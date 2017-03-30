global class RLLP_PaymentContactRollup_BATCH implements Database.Batchable<sObject> {
	global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('select Id, Total_Payments__c from Contact');
    }
    
    global void execute(Database.BatchableContext bc, List<Contact> conList) {
        Map<Id, Contact> conMap = new Map<Id, Contact>(conList);
        for (Id conId : conMap.keySet()) {
            conMap.get(conId).Total_Payments__c = 0.0;
            // reset more rollups here
        }
        
		// find opportunity-contact roles marked primary for these contacts
        List<OpportunityContactRole> ocrs = [select OpportunityId, ContactId from OpportunityContactRole
                                                    where ContactId in :conMap.keySet()
                                            		and isPrimary = true]; // TODO: more filters necessary?
        
        Map<Id, Id> oppId_to_conId = new Map<Id, Id>();
        for (OpportunityContactRole ocr : ocrs) oppId_to_conId.put(ocr.OpportunityId, ocr.ContactId);
        
		// find paid payments on opportunities for which the contacts have a primary OCR
        List<npe01__OppPayment__c> pmts = [select Id, npe01__Payment_Amount__c, npe01__Opportunity__c
                                          from npe01__OppPayment__c
                                          where npe01__Opportunity__c in :oppId_to_conId.keySet()
                                          and npe01__Paid__c = true];
        
		// loop through payments, accumulating the payment amounts on the contact
        for (npe01__OppPayment__c pmt : pmts) {
            conMap.get(oppId_to_conId.get(pmt.npe01__Opportunity__c)).Total_Payments__c +=
                					pmt.npe01__Payment_Amount__c;
        }
        
		// update the contacts
        update conList;
    }
    
    global void finish(Database.BatchableContext bc) {

    }
}
