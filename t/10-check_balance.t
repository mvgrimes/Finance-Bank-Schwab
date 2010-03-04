use strict;
use warnings;

use Test::More;
use Finance::Bank::Schwab;

my $userid = $ENV{F_C_SCHWAB_USERID};
my $passwd = $ENV{F_C_SCHWAB_PASSWD};

plan skip_all => "- Need password to fully test. To enable tests set F_C_SCHWAB_USERID F_C_SCHWAB_PASSWD environment variables."
		unless $userid && $passwd;
plan tests => 3;

# Test set 2 -- create client with ordered list of arguements
my @accounts = Finance::Bank::Schwab->check_balance(
    			'username'	=> $userid,
    			'password'	=> $passwd,
                # 'log' => 'tmp.log',
                # 'content' => 'tmp.log',
		 );

ok @accounts, "check_balance returned a non-empty array";
isa_ok $accounts[0], 'Finance::Bank::Schwab::Account', "check_balance returned a new Finance::Bank::Schwab::Account object";
ok $accounts[0]->account_no, 'Returned a non-false value for the account number';

for (@accounts){
	printf "# %18s : %8s / %8s : \$ %9.2f\n",
	    $_->name, $_->sort_code, $_->account_no, $_->balance;
}

