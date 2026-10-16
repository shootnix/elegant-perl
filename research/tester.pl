use v5.32;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib", "$FindBin::Bin/lib";

#use Currency;


use Customer;
use Customer::BillingInfo;
use Billing;

my $c = Customer->new(
    id => 101,
    billing_info => Customer::BillingInfo->new(
        balance => 101,
        account_num => 100110,
        uuid => 'UUID-1010-ID',
    )->as_cap('Public'),
    contact_info => 'Contact Info',
    first_name => 'Bill',
    last_name => 'Clinton',
    session_data => 'Session Data',
);

my $billing = Billing->new(customer => $c->as_cap('Billing'));
say 'Account: ' . $billing->billing_info()->account_num;
say 'Balance: ' . $billing->balance_info();

#my $a = Currency->new(amount => 100, currency => 'USD');
#my $b = Currency->new(amount =>   1, currency => 'USD');

#my $c = $a->plus($b);


#warn Dumper $c;
#warn $c->to_string();
