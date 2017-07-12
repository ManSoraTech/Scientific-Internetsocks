def getKeys(enable_custom_method):
	if enable_custom_method:
		return ['port', 'flow_up', 'flow_down', 'lastConnTime', 'transfer', 'sspwd', 'method', 'protocol', 'obfs', 'enable', 'plan' ]
	else:
		return ['port', 'flow_up', 'flow_down', 'lastConnTime', 'transfer', 'sspwd', 'enable', 'plan']
	#return ['port', 'u', 'd', 'transfer_enable', 'passwd', 'enable', 'plan' ] # append the column name 'plan'

def isTurnOn(row):
	return True
	#return row['plan'] == 'B' # then judge here

