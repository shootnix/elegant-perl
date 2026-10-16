use v5.32;
use warnings;

package Customer::BillingInfo {
    use Elegant::Perl;

    field balance => 'Num';
    field account_num => 'Num';
    field uuid => 'Str';

    cap 'Public' => {
        balance => sub($self) { value($self, 'balance') },
        account_num => sub($self) { value($self, 'account_num') },
        uuid => sub($self) { value($self, 'uuid') },
    };
}

1;
