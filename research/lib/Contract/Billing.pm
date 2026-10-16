use v5.32;
use warnings;

package Contract::Billing {
    use Elegant::Perl::Contract;

    sub billing_info 
        :Builder 
        :Expects()
        :Returns(Customer::BillingInfo::Cap::Public);

    sub balance_info 
        :Builder
        :Expects()
        :Returns(Num);
}

1;
