/* Right now, this fills several fields on Contact with totals for
 * paid Payments on opportunities for which the contact is the primary opportunity-contact role.
 * 
 *
 * TODO:
 * - deal with multicurrency. Any NPSP settings to take care of?
 * - I think I have accounted for fiscal year preferences, N-day, and exclusions.
 * - add logic to update only those contacts whose rollup values change?
 * - make real-time (TDTM)
 * - figure out how to merge into NPSP
 */

global class RLLP_PaymentContactRollup_BATCH implements
	Database.Batchable<sObject>, Database.stateful {
	
	private Date currentYearStart;
    private Integer ndays;
    // "need local vars b/c dynamic soql is stupid" see comment in NPSP code
    private Set<String> typesExcluded;
    private Set<Id> recTypesExcluded;
    // All of these must be handled correctly in the accumulation loop,
    // otherwise will be $0.00 or another wrong number:
    private List<String> rollupFieldNames = new List<String> {'Total_Payments__c', 'PaymentAmountLastYear__c',
                                      'PaymentAmount2YearsAgo__c', 'PaymentAmountThisYear__c',
            							'PaymentAmountLastNDays__c'};
	
	global Database.QueryLocator start(Database.BatchableContext bc) {
		RLLP_OppRollup_UTIL oppRollupUtil = new RLLP_OppRollup_UTIL();
        typesExcluded = RLLP_OppRollup_UTIL.oppTypesToExcludeCons;
        recTypesExcluded = RLLP_OppRollup_UTIL.recordTypesToExcludeCons;
        
        if (RLLP_OppRollup_UTIL.useFiscalYear) {
            currentYearStart = Date.newInstance(Date.Today().Year(), [SELECT FiscalYearStartMonth FROM Organization LIMIT 1].FiscalYearStartMonth, 1);
            if (currentYearStart > Date.Today()) 
                currentYearStart = currentYearStart.addYears(-1);
        } else {
            currentYearStart = Date.newInstance(Date.Today().Year(), 1, 1);
        }
        
        ndays = (Integer) RLLP_OppRollup_UTIL.hh_settings.npo02__Rollup_N_Day_Value__c;
        
        String contactQuery = 'Select Id';
        for (String rollupFieldName : rollupFieldNames) contactQuery += ', ' + rollupFieldName;
        contactQuery += ' from Contact';
        
        return Database.getQueryLocator(contactQuery);
    }
    
    global void execute(Database.BatchableContext bc, List<Contact> conList) {
    	
        Map<Id, Contact> conMap = new Map<Id, Contact>(conList);
        for (Id conId : conMap.keySet()) { // TODO: better way to iterate?
            Contact con = conMap.get(conId);
            // reset rollups to 0.0 so we can total them:
            for (String rollupFieldName : rollupFieldNames) con.put(rollupFieldName, 0.0);
        }
        
        // find opportunity-contact roles marked primary for these contacts
        List<OpportunityContactRole> ocrs = [select OpportunityId, ContactId from OpportunityContactRole
                                                    where ContactId in :conMap.keySet()
                                             		and Opportunity.RecordTypeId not in :recTypesExcluded
                                             		and Opportunity.Type not in :typesExcluded
                                            		and isPrimary = true]; // TODO: more filters necessary?
        
        Map<Id, Id> oppId_to_conId = new Map<Id, Id>();
        for (OpportunityContactRole ocr : ocrs) oppId_to_conId.put(ocr.OpportunityId, ocr.ContactId);
        
        // find paid payments on opportunities for which the contacts have a primary OCR
        List<npe01__OppPayment__c> pmts = [select Id, npe01__Payment_Amount__c, npe01__Opportunity__c,
        										npe01__Payment_Date__c
                                          from npe01__OppPayment__c
                                          where npe01__Opportunity__c in :oppId_to_conId.keySet()
                                          and npe01__Paid__c = true];
        
        // loop through payments, accumulating the payment amounts on the contact
        for (npe01__OppPayment__c pmt : pmts) {
        	Contact con = conMap.get(oppId_to_conId.get(pmt.npe01__Opportunity__c));
            con.Total_Payments__c += pmt.npe01__Payment_Amount__c;
            
            if (pmt.npe01__Payment_Date__c <= Date.today() &&
                pmt.npe01__Payment_Date__c >= Date.today().addDays(-ndays))
                con.PaymentAmountLastNDays__c += pmt.npe01__Payment_Amount__c;
                					
            if (pmt.npe01__Payment_Date__c < currentYearStart.addYears(1)) {
                if (pmt.npe01__Payment_Date__c >= currentYearStart)
                    con.PaymentAmountThisYear__c += pmt.npe01__Payment_Amount__c;
                else if (pmt.npe01__Payment_Date__c >= currentYearStart.addYears(-1))
                    con.PaymentAmountLastYear__c += pmt.npe01__Payment_Amount__c;
                else if (pmt.npe01__Payment_Date__c >= currentYearStart.addYears(-2))
                    con.PaymentAmount2YearsAgo__c += pmt.npe01__Payment_Amount__c;
            }

        }
        
        // update the contacts
        update conList;
    }
    
    global void finish(Database.BatchableContext bc) { }
}
