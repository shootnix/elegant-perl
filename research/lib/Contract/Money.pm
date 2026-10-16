use v5.32;
use warnings;

package Contract::Money {
    use Elegant::Perl::Contract;

    sub plus :Builder :Expects(Contract::Money) :Returns(Contract::Money);
}

1;