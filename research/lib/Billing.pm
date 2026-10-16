use v5.32;
use warnings;

package Billing {
    use Elegant::Perl;

    implements 'Contract::Billing';

    field customer => 'Customer::Cap::Billing';

    sub billing_info($self) {
        my $customer = value($self, 'customer');
        return $customer->billing_info;
    }

    sub balance_info($self) {
        my $customer = value($self, 'customer');
        return $customer->balance;
    }
}

1;
