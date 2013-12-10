# NAME

Finance::Bank::Schwab - Check your account balances at Charles Schwab

# VERSION

version 2.03

# SYNOPSIS

    use Finance::Bank::Schwab;
    my @accounts = Finance::Bank::Schwab->check_balance(
        username     => "xxxxxxxxxxxx",
        password     => "12345",
        get_position => 1,
    );

    for ( @accounts ) {
        printf "%20s : %8s / %8s : USD %9.2f USD %9.2f\n",
            $_->name, $_->sort_code, $_->account_no, $_->cash, $_->balance;

      for my $position ( @{ $_->positions } ) {
          printf "# \t%-10s %-10s %10s Shares \@ \$%-15s\n",
            $position->type,
            $position->symbol,
            $position->quantity,
            $position->price;
      }
      print "\n";

    }

# DESCRIPTION

This module provides a rudimentary interface to the Charles Schwab site.
You will need either `Crypt::SSLeay` or `IO::Socket::SSL` installed 
for HTTPS support to work. `WWW::Mechanize` is required.  If you encounter
odd errors, install `Net::SSLeay` and it may resolve itself.

# CLASS METHODS

## check\_balance()

    check_balance( usename => $u, password => $p )

Return an array of account objects, one for each of your bank accounts.

# OBJECT METHODS

    $ac->name
    $ac->sort_code
    $ac->account_no

Return the account name, sort code and the account number. The sort code is
just the name in this case, but it has been included for consistency with 
other Finance::Bank::\* modules.

    $ac->balance

Return the account balance as a signed floating point value.

    $ac->cash

Return the cash balance as a signed floating point value. This is useful if
the account has margin borrowing as the balance alone doesn't do justice.

    $ac->positions

References an array of hash references. Each hash holds the following:
	      ->symbol		(String)
	      ->quantity	(Signed Float)
	      ->price		(Signed Float)
	      ->type		(Stock/Bond/Cash/Unknown)

# WARNING

This warning is verbatim from Simon Cozens' `Finance::Bank::LloydsTSB`,
and certainly applies to this module as well.

This is code for __online banking__, and that means __your money__, and
that means __BE CAREFUL__. You are encouraged, nay, expected, to audit
the source of this module yourself to reassure yourself that I am not
doing anything untoward with your banking data. This software is useful
to me, but is provided under __NO GUARANTEE__, explicit or implied.

# THANKS

Simon Cozens for `Finance::Bank::LloydsTSB`. The interface to this module,
some code and the pod were all taken from Simon's module.

The ability to retrieve stock/bond/etc positions was contributed by Ryan Clark
<ryan.clark9@gmail.com>.

# AUTHOR

Mark Grimes <mgrimes@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Mark Grimes <mgrimes@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
