package Finance::Bank::Schwab;

###########################################################################
# Finance::Bank::Schwab
# Mark Grimes
#
# Check you account blances at Charles Schwab.
# Copyright (c) 2005-2009 Mark Grimes (mgrimes@cpan.org).
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.
#
# Parts of this package were inspired by:
#   Simon Cozens - Finance::Bank::Lloyds module
# Thanks!
#
###########################################################################
use strict;
use warnings;

use Carp;
use WWW::Mechanize;

our $VERSION = '1.16';

our $ua = WWW::Mechanize->new(
    env_proxy  => 1,
    keep_alive => 1,
    timeout    => 30,
);

sub check_balance {
    my ( $class, %opts ) = @_;
    my $content;

    if ( $opts{content} ) {

        # If we give it a file, use the file rather than downloading
        open my $fh, "<", $opts{content} or confess;
        $content = do { local $/ = undef; <$fh> };
        close $fh;

    } else {

        croak "Must provide a password" unless exists $opts{password};
        croak "Must provide a username" unless exists $opts{username};

        my $self = bless {%opts}, $class;

        $ua->get("https://investing.schwab.com/trading/start")
          or croak "couldn't load inital page";
        $ua->submit_form(
            form_name => 'SignonForm',
            fields    => {
                'SignonAccountNumber' => $opts{username},
                'SignonPassword'      => $opts{password},
            },
        ) or croak "couldn't sign on to account";

        $content = $ua->content;
    }

    if ( $opts{log} ) {

        # Dump to the filename passed in log
        open( my $fh, ">", $opts{log} ) or confess;
        print $fh $content;
        close $fh;
    }

    my @balance_info = $content =~ m!
                <tr[^>]*>                   \s*

                    <td\ class="nWrap">     \s*
                        <a[^>]*>            \s*
                            ([\d\-.]+)      # account number
                        </a>                \s*
                        (?: <sup>[^<]*</sup> )?
                        [^<]*
                    </td>                   \s*

                    <td[^>]*>               \s*
                        <span[^>]*>         \s*
                            ([^<]+)         # account name
                        </span>             \s*
                    </td>                   \s*
                        
                    <td[^>]*>               \s*
                        <span[^>]*>         \s*
                            [^<]*           # cash & cash investments
                        </span>             \s*
                    </td>                   \s*

                    <td[^>]*>               \s*
                        <span[^>]*>         \s*
                        (-?\$[\d,\.]+)      # account balance
                        </span>           
            !sxig;

    # use Data::Dumper;
    # print Dumper \@balance_info;

    my @accounts;
    while (@balance_info) {
        my $number  = shift @balance_info;
        my $name    = shift @balance_info;
        my $balance = shift @balance_info;
        $balance =~ s/[\$,]//xg;

        push @accounts, (
            bless {
                balance    => $balance,
                name       => $name,
                sort_code  => $name,
                account_no => $number,
                ## parent       => $self,
                statement => undef,
            },
            "Finance::Bank::Schwab::Account"
        );
    }
    return @accounts;
}

package Finance::Bank::Schwab::Account;

# Basic OO smoke-and-mirrors Thingy
no strict;

sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/.*:://x;
    return $self->{$AUTOLOAD};
}

1;

__END__

# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Finance::Bank::Schwab - Check your Charles Schwab accounts from Perl

=head1 SYNOPSIS

  use Finance::Bank::Schwab;
  my @accounts = Finance::Bank::Schwab->check_balance(
      username => "xxxxxxxxxxxx",
      password => "12345",
  );

  foreach (@accounts) {
      printf "%20s : %8s / %8s : USD %9.2f\n",
      $_->name, $_->sort_code, $_->account_no, $_->balance;
  }
  
=head1 DESCRIPTION

This module provides a rudimentary interface to the Charles Schwab site
at C<https://investing.schwab.com/trading/start>. 
You will need either C<Crypt::SSLeay> or C<IO::Socket::SSL> installed 
for HTTPS support to work. C<WWW::Mechanize> is required.

=head1 CLASS METHODS

=head2 check_balance()

  check_balance( usename => $u, password => $p )

Return an array of account objects, one for each of your bank accounts.

=head1 OBJECT METHODS

  $ac->name
  $ac->sort_code
  $ac->account_no

Return the account name, sort code and the account number. The sort code is
just the name in this case, but it has been included for consistency with 
other Finance::Bank::* modules.

  $ac->balance

Return the account balance as a signed floating point value.

=head1 WARNING

This warning is verbatim from Simon Cozens' C<Finance::Bank::LloydsTSB>,
and certainly applies to this module as well.

This is code for B<online banking>, and that means B<your money>, and
that means B<BE CAREFUL>. You are encouraged, nay, expected, to audit
the source of this module yourself to reassure yourself that I am not
doing anything untoward with your banking data. This software is useful
to me, but is provided under B<NO GUARANTEE>, explicit or implied.

=head1 THANKS

Simon Cozens for C<Finance::Bank::LloydsTSB>. The interface to this module,
some code and the pod were all taken from Simon's module.

=head1 AUTHOR

Mark Grimes <mgrimes@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-9 by mgrimes

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
