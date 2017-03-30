@isTest
public class RLLP_PaymentContactRollup_TEST {
	public static testMethod void testContactPaymentRollup() {
        
        Account a = new Account(Name = 'Test Payment Rollup account'); // , RecordTypeId=hhAcctRecordType);
        insert a;
        
        Contact con1 = new Contact(FirstName='FirstBlah1', LastName='LastBlah1', AccountId=a.id);
        Contact con2 = new Contact(FirstName='FirstBlah2', LastName='LastBlah2', AccountId=a.id);
        insert con1;
        insert con2;
        
        Opportunity opp1 = new Opportunity(Name='Test1', Amount=100, CloseDate=Date.parse('1/1/2015'),
                                           npe01__Contact_Id_for_Role__c = con1.id,
                                          StageName='Closed Won');
        Opportunity opp2 = new Opportunity(Name='Test2', Amount=200, CloseDate=Date.parse('1/1/2015'),
                                          StageName='Closed Won');
        insert opp1;
        insert opp2;
        
        OpportunityContactRole role = new OpportunityContactRole(ContactId = con2.id,
                                                                OpportunityId = opp2.id,
                                                                IsPrimary = true,
                                                                Role = 'Donor');
        insert role;
        
		//Database.executeBatch(new ContactPaymentRollup2_BATCH());
		Test.StartTest();
        Id batchProcessId = Database.executeBatch(new RLLP_PaymentContactRollup_BATCH());
        Test.stopTest();
        
		Contact con1_after = [select id, Total_Payments__c from Contact where id = :con1.id][0];        
        Contact con2_after = [select id, Total_Payments__c from Contact where id = :con2.id][0];
        
        System.assertEquals(100, con1_after.Total_Payments__c);
        System.assertEquals(200, con2_after.Total_Payments__c);
    }
}
