use v5.32;
use warnings;

package Contract::Stringer {
    use Elegant::Perl::Contract;

    sub to_string :Builder :Returns(Str);
}


1;