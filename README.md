# NPSP-practice-payment-rollups

Ever want payment rollups? I do!

These classes try to implement payment rollup fields for the Nonprofit Success Pack. So far, this is a class that calculates payment totals on the Contact object. It fills fields for total payments ever, total payments this year, the past year, the year before that, and the total in the past N days.

Also planned: dates of first and last payment, etc.

Just like the NPSP rollup fields, the class calculates the totals according to NPSP preferences (whether or not to use fiscal year, the N-day preference, and opportunity exclusions).

This does not yet calculate rollups in real time; it is schedulable batch Apex.

This class depends on several others from the Nonprofit Success Pack. At this point it works only with the unmanaged version of the NPSP.
