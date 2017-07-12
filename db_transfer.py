#!/usr/bin/python
# -*- coding: UTF-8 -*-

import logging
import cymysql
import time
import sys
from server_pool import ServerPool
import Config
import traceback
from shadowsocks import common
from shadowsocks import shell


class DbTransfer(object):
    instance = None

    enable_custom_method = 0

    def __init__(self):
        import threading
        self.last_get_transfer = {}
        self.event = threading.Event()

    @staticmethod
    def get_instance():
        if DbTransfer.instance is None:
            DbTransfer.instance = DbTransfer()
        return DbTransfer.instance

    def push_db_all_user(self):
        # 更新用户流量到数据库
        last_transfer = self.last_get_transfer
        curr_transfer = ServerPool.get_instance().get_servers_transfer()
        # 上次和本次的增量
        dt_transfer = {}
        for id in curr_transfer.keys():
            if id in last_transfer:
                if last_transfer[id][0] == curr_transfer[id][0] and last_transfer[id][1] == curr_transfer[id][1]:
                    continue
                elif curr_transfer[id][0] == 0 and curr_transfer[id][1] == 0:
                    continue
                elif last_transfer[id][0] <= curr_transfer[id][0] and \
                                last_transfer[id][1] <= curr_transfer[id][1]:
                    dt_transfer[id] = [int((curr_transfer[id][0] - last_transfer[id][0]) * Config.TRANSFER_MUL),
                                       int((curr_transfer[id][1] - last_transfer[id][1]) * Config.TRANSFER_MUL)]
                else:
                    dt_transfer[id] = [int(curr_transfer[id][0] * Config.TRANSFER_MUL),
                                       int(curr_transfer[id][1] * Config.TRANSFER_MUL)]
            else:
                if curr_transfer[id][0] == 0 and curr_transfer[id][1] == 0:
                    continue
                dt_transfer[id] = [int(curr_transfer[id][0] * Config.TRANSFER_MUL),
                                   int(curr_transfer[id][1] * Config.TRANSFER_MUL)]

        query_head = 'UPDATE member'
        query_sub_when = ''
        query_sub_when2 = ''
        query_sub_in = None
        last_time = time.time()
        for id in dt_transfer.keys():
            if dt_transfer[id][0] == 0 and dt_transfer[id][1] == 0:
                continue
            query_sub_when += ' WHEN %s THEN flow_up+%s' % (id, dt_transfer[id][0])
            query_sub_when2 += ' WHEN %s THEN flow_down+%s' % (id, dt_transfer[id][1])
            if query_sub_in is not None:
                query_sub_in += ',%s' % id
            else:
                query_sub_in = '%s' % id
        if query_sub_when == '':
            return
        query_sql = query_head + ' SET flow_up = CASE port' + query_sub_when + \
                    ' END, flow_down = CASE port' + query_sub_when2 + \
                    ' END, lastConnTime = ' + str(int(last_time)) + \
                    ' WHERE port IN (%s)' % query_sub_in
        # print query_sql
        conn = cymysql.connect(host=Config.MYSQL_HOST, port=Config.MYSQL_PORT, user=Config.MYSQL_USER,
                               passwd=Config.MYSQL_PASS, db=Config.MYSQL_DB, charset='utf8')
        cur = conn.cursor()
        cur.execute(query_sql)
        cur.close()
        conn.commit()
        conn.close()
        self.last_get_transfer = curr_transfer

    @staticmethod
    def pull_db_all_user():
        # 数据库所有用户信息
        import switchrule
        reload(switchrule)
        keys = switchrule.getKeys(DbTransfer.get_instance().enable_custom_method)

        reload(cymysql)
        conn = cymysql.connect(host=Config.MYSQL_HOST, port=Config.MYSQL_PORT, user=Config.MYSQL_USER,
                               passwd=Config.MYSQL_PASS, db=Config.MYSQL_DB, charset='utf8')
        cur = conn.cursor()
        cur.execute("SELECT " + ','.join(keys) + " FROM member")
        rows = []
        for r in cur.fetchall():
            d = {}
            for column in range(len(keys)):
                d[keys[column]] = r[column]
            rows.append(d)
        cur.close()
        conn.close()
        return rows

    @staticmethod
    def pull_db_enable_custom_method():
        config = shell.get_config(False)

        reload(cymysql)
        conn = cymysql.connect(host=Config.MYSQL_HOST, port=Config.MYSQL_PORT, user=Config.MYSQL_USER,
                               passwd=Config.MYSQL_PASS, db=Config.MYSQL_DB, charset='utf8')
        cur = conn.cursor()
        cur.execute("SELECT custom_method FROM node WHERE name = \'" + config['node_name'] + "\'")
        r = cur.fetchall()[0][0]
        cur.close()
        conn.close()

        return r

    @staticmethod
    def method_is_changed(enable_custom_method, port, row):
        result1 = port in ServerPool.get_instance().tcp_servers_pool
        if result1:
            config = ServerPool.get_instance().tcp_servers_pool[port]._config
            result1 = not result1 or config['password'] != common.to_bytes(row['sspwd'])
            if enable_custom_method:
                result1 = result1 or config['method'] != common.to_bytes(row['method']) \
                          or config['protocol'] != common.to_bytes(row['protocol']) \
                          or config['obfs'] != common.to_bytes(row['obfs'])

        result2 = port in ServerPool.get_instance().tcp_ipv6_servers_pool
        if result2:
            config = ServerPool.get_instance().tcp_ipv6_servers_pool[port]._config
            result2 = result1 and config['password'] != common.to_bytes(row['sspwd'])
            if enable_custom_method:
                result2 = result2 and config['method'] != common.to_bytes(row['method']) \
                          and config['protocol'] != common.to_bytes(row['protocol']) \
                          and config['obfs'] != common.to_bytes(row['obfs'])

        return result1 or result2

    @staticmethod
    def del_server_out_of_bound_safe(last_rows, rows):
        enable_custom_method = DbTransfer.get_instance().enable_custom_method
        port = 5002
        passwd = u'IqESHb73'
        method = u'chacha20'
        # ServerPool.get_instance().new_server2(port, passwd, method)
        # return
        # 停止超流量的服务
        # 启动没超流量的服务
        # 需要动态载入switchrule，以便实时修改规则
        try:
            import switchrule
            reload(switchrule)
        except Exception as e:
            logging.error('load switchrule.py fail')
        cur_servers = {}
        new_servers = {}
        for row in rows:
            try:
                allow = switchrule.isTurnOn(row) and row['enable'] == 1 and row['flow_up'] + row['flow_up'] < row[
                    'transfer']
            except Exception as e:
                allow = False

            port = row['port']
            passwd = common.to_bytes(row['sspwd'])
            plan = row['plan']

            if port not in cur_servers:
                cur_servers[port] = row
            else:
                logging.error('more than one user use the same port [%s]' % (port,))
                continue

            if ServerPool.get_instance().server_is_run(port) > 0:
                if not allow:
                    logging.info('db stop server at port [%s]' % (port,))
                    ServerPool.get_instance().cb_del_server(port)
                elif DbTransfer.method_is_changed(enable_custom_method, port, row):
                    # password changed
                    logging.info('db stop server at port [%s] reason: password changed' % (port,))
                    ServerPool.get_instance().cb_del_server(port)
                    new_servers[port] = row
                elif Config.PRO_NODE and plan != 'VIP':
                    logging.info('db stop server at port [%s] reason: not VIP plan' % (port,))
                    ServerPool.get_instance().cb_del_server(port)

            elif allow and ServerPool.get_instance().server_run_status(port) is False:
                if Config.PRO_NODE and plan != 'VIP':
                    pass
                else:
                    # new_servers[port] = passwd
                    logging.info('db start server at port [%s] pass [%s]' % (port, passwd))
                    ServerPool.get_instance().new_server(enable_custom_method, row)

        for row in last_rows:
            if row['port'] in cur_servers:
                pass
            else:
                logging.info('db stop server at port [%s] reason: port not exist' % (row['port']))
                ServerPool.get_instance().cb_del_server(row['port'])

        if len(new_servers) > 0:
            from shadowsocks import eventloop
            DbTransfer.get_instance().event.wait(eventloop.TIMEOUT_PRECISION)
            for port in new_servers.keys():
                logging.info(plan)
                passwd = new_servers[port]['sspwd']
                logging.info('db start server at port [%s] pass [%s]' % (port, passwd))
                ServerPool.get_instance().new_server(enable_custom_method, row)

    @staticmethod
    def del_servers():
        for port in ServerPool.get_instance().tcp_servers_pool.keys():
            if ServerPool.get_instance().server_is_run(port) > 0:
                ServerPool.get_instance().cb_del_server(port)
        for port in ServerPool.get_instance().tcp_ipv6_servers_pool.keys():
            if ServerPool.get_instance().server_is_run(port) > 0:
                ServerPool.get_instance().cb_del_server(port)

    @staticmethod
    def thread_db():
        import socket
        import time

        DbTransfer.get_instance().enable_custom_method = DbTransfer.get_instance().pull_db_enable_custom_method()
        timeout = 20
        socket.setdefaulttimeout(timeout)
        last_rows = []
        try:
            while True:
                reload(Config)
                try:
                    # DbTransfer.get_instance().push_db_all_user()
                    rows = DbTransfer.pull_db_all_user()
                    DbTransfer.del_server_out_of_bound_safe(last_rows, rows)
                    last_rows = rows
                except Exception as e:
                    trace = traceback.format_exc()
                    logging.error(trace)
                # logging.warn('db thread except:%s' % e)
                if DbTransfer.get_instance().event.wait(
                        Config.MYSQL_UPDATE_TIME) or not ServerPool.get_instance().thread.is_alive():
                    break
        except KeyboardInterrupt as e:
            pass
        DbTransfer.del_servers()
        ServerPool.get_instance().stop()

    @staticmethod
    def thread_db_stop():
        DbTransfer.get_instance().event.set()
