use v5.32;
use warnings;

package Currency {
    use Elegant::Perl;

    implements 'Contract::Stringer';
    implements 'Contract::Money';

    field 'amount';
    field 'currency';

    sub to_string($self) {
        return sprintf "%.d %s", value($self, 'amount'), value($self, 'currency');
    }

    sub plus($self, $other) {
        return Currency->new(
            currency => value($self, 'currency'),
            amount => value($self, 'amount') + value($other, 'amount'),
        );
    }
}

1;