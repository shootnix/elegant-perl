use v5.32;
use warnings;

package Customer {
    use Elegant::Perl;

    field 'id';
    field 'billing_info' => 'Customer::BillingInfo::Cap::Public';
    field 'contact_info';
    field 'first_name';
    field 'last_name';
    field 'session_data';


    cap 'Billing' => {
        billing_info => sub($self) {
            return value($self, 'billing_info');
        },  
        balance => sub($self) {
            return value($self, 'billing_info')->balance;
        }
    };

    cap 'Public' => {
        first_name => sub($self) { value($self, 'first_name'); },
        last_name  => sub($self) { value($self, 'last_name'); },
    };

    #cap 'Persistence' => {
    #    id           => sub($self) { value($self, 'id') },
    #    billing_info => sub($self) { value($self, 'billing_info') },
    #    contact_info => sub($self) { value($self, 'contact_info') },
    #    first_name   => sub($self) { value($self, 'first_name') },
    #    last_name    => sub($self) { value($self, 'last_name') },
    #};

    #cap 'Session' => {
    #    id           => sub($self) { value($self, 'id') },
    #    session_data => sub($self) { value($self, 'session_data') },
    #};
}

package Customer::ContactInfo {
    use Elegant::Perl;

    field email => 'Str';
    field phone => 'Str';
}

#package Billing {
#    use Elegant::Perl;
#
#    field 'customer', 'Customer::Billing';
#
#    sub balance($self) {
#        my $customer = value($self, 'customer');
#        my $billing_info = value($customer, 'billing_info');
#        return sprintf "%.2d", value($billing_info, 'balance') / 100;
#    }
#}



1;
