package Finance::Bank::Schwab;

# ABSTRCT: Check your account balances at Charles Schwab.

use strict;
use warnings;

use Carp;
use WWW::Mechanize;
use HTML::TableExtract;

our $VERSION = '2.03';

our $ua = WWW::Mechanize->new(
    env_proxy  => 1,
    keep_alive => 1,
    timeout    => 30,
    cookie_jar => {},
);

# Debug logging:
# $ua->default_header( 'Accept-Encoding' => scalar HTTP::Message::decodable() );
# $ua->add_handler( "request_send",  sub { shift->dump; return } );
# $ua->add_handler( "response_done", sub { shift->dump; return } );

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

        # Get the login page
        $ua->get(
            'https://client.schwab.com/Login/SignOn/CustomerCenterLogin.aspx')
          or croak "couldn't load inital page";

        # Find the login form, change the action url, then set the username/
        # password and submit
        my $login_form = $ua->form_name('aspnetForm')
          or croak "Couldn't find the login form";
        $login_form->action(
            'https://client.schwab.com/Login/SignOn/signon.ashx')
          or croak "Couldn't update the action url on login form";
        my $username_field =
          'ctl00$WebPartManager1$CenterLogin$LoginUserControlId$txtLoginID';
        $login_form->value( $username_field => $opts{username} );
        $login_form->value( 'txtPassword'   => $opts{password} );
        $ua->submit() or croak "couldn't sign on to account";

        $content = $ua->content;
    }

    if ( $opts{log} ) {

        # Dump to the filename passed in log
        open( my $fh, ">", $opts{log} ) or confess;
        print $fh $content;
        close $fh;
    }

    my @accounts;

    my $te = HTML::TableExtract->new(
        headers => [
            'Account',                       'Name',
            '(?:Value|Available\s+Balance)', '(?:Cash|Balance\sOwed)'
        ],
        keep_html => 1,
        ## decode    => 0,
    );

    {

        # HTML::TableExtract warns about undef value with keep_html option
        $SIG{__WARN__} = sub {
            warn @_ unless $_[0] =~ /uninitialized value in subroutine entry/;
        };
        $te->parse($content);
    }

    for my $ts ( $te->tables ) {

        # print "Table (", join( ',', $ts->coords ), "):\n";

        for my $row ( $ts->rows ) {
            next if $row->[1] =~ /Totals/;    # Skip total rows

            # Remove any superscripts
            $row->[0] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;
            $row->[1] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;
            $row->[2] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;
            $row->[3] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;

            # Simple regex to strip html from cells
            $row->[0] =~ s{<[^>]*>}{}mg;
            $row->[1] =~ s{<[^>]*>}{}mg;
            $row->[2] =~ s{<[^>]*>}{}mg;
            $row->[3] =~ s{<[^>]*>}{}mg;

            $_ =~ s{^\s*|\s*$}{}g for @$row;    # Trim whitespace
            $row->[0] =~ s{^([\d.-]+).*$}{$1}s; # Strip all but num from name
            $row->[2] =~ s/[\$,]//xg;           # Remove $ and , from value
            $row->[3] =~ s/[\$,]//xg;           # Remove $ and , from value

            # If this is an account with positions, let's go grab that data, too.
            if ( $row->[0] =~ /\d{4}-\d{4}/ ) {
                my @positions;
                my $acct = $row->[0];
                $acct =~ s/-//;

                if ( $opts{content} ) {

                    # Read in the available files
                    open my $fh, "<", $acct or confess;
                    $content = do { local $/ = undef; <$fh> };
                    close $fh;
                } else {

                    # Grab the data from the Schwab site
                    $ua->get(
                        "https://client.schwab.com/Accounts/Positions/AccountPositionsSummary.aspx?selAcct=$acct"
                    ) or croak "couldn't load position page for $acct";
                    $content = $ua->content;

                    if ( $opts{log} ) {

                        # Dump to a log file (based on acct #)
                        open( my $fh, ">", $acct ) or confess;
                        print $fh $content;
                        close $fh;
                    }
                }

                my $te = HTML::TableExtract->new(
                    headers   => [ 'Symbol', 'Quantity', 'Price', 'Change' ],
                    keep_html => 1,
                    ## decode    => 0,
                );

                {

                    # HTML::TableExtract warns about undef value with keep_html option
                    $SIG{__WARN__} = sub {
                        warn @_
                          unless $_[0] =~
                          /uninitialized value in subroutine entry/;
                    };
                    $te->parse($content);
                }

                for my $ts ( $te->tables ) {

                    # print "Table (", join( ',', $ts->coords ), "):\n";
                    no warnings 'uninitialized';

                    for my $row ( $ts->rows ) {
                        next
                          if $row->[2] eq ''
                          ; # Skip empty rows (There's an oddity here where it's most efficient to check the Price column)
                        next if $row->[0] =~ /Total/;    # Skip total rows

                        # Remove any superscripts
                        $row->[0] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;
                        $row->[1] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;
                        $row->[2] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;
                        $row->[3] =~ s{<sup[^>]*>[^<]*</sup>}{}mg;

                        # Let's call out if these are stocks/bonds/cash/unknown in case the user finds this helpful
                        if ( $row->[0] =~ m/SymbolRouting/ ) {

                            # This is a Stock
                            $row->[4] = 'Stock';
                        } elsif ( $row->[0] =~ m/TradeBondSuperPopUp/ ) {

                            # This is a Bond.  James Bond.
                            $row->[4] = 'Bond';
                        } elsif ( $row->[0] =~ m/Cash/ ) {

                            # This is Cash
                            $row->[4] = 'Cash';
                        } else {

                            # I don't know what this is
                            $row->[4] = 'Unknown';
                        }

                        # Simple regex to strip html from cells
                        $row->[0] =~ s{<[^>]*>}{}mg;
                        $row->[1] =~ s{<[^>]*>}{}mg;
                        $row->[2] =~ s{<[^>]*>}{}mg;
                        $row->[3] =~ s{<[^>]*>}{}mg;

                        $_ =~ s{^\s*|\s*$}{}g for @$row;    # Trim whitespace
                        $row->[1] =~ s/[,]//xg;      # Remove , from value
                        $row->[2] =~ s/[\$,]//xg;    # Remove $ and , from value
                        $row->[3] =~ s/[\$,]//xg;    # Remove $ and , from value

                        if ( $row->[0] =~ m/Cash/ ) {

                            # The "Cash & Cash Investments" line is screwy, where the value is in the "Change" column.  Let's correct it and set "shares" to be 1, but price to be value.
                            $row->[0] =
                              'Cash';   # Trim off the "& Cash Investments" part
                            $row->[1] = 1;
                            $row->[2] = $row->[3];
                        }

                        if ( $row->[4] =~ m/Bond/ ) {

                            # The Bond types use funny math, where bond prices are shown per 100 shares.  Correction is to divide price or quantity by 100.  I elect price.
                            $row->[2] = $row->[2] / 100;
                        }

                        push @positions,
                          {
                            symbol   => $row->[0],
                            quantity => $row->[1],
                            price    => $row->[2],
                            type     => $row->[4] };
                    }
                }
                $row->[4] = \@positions;

            } else {

                # Probably a banking account, ignore for now
                $row->[4] = '';
            }

            push @accounts, (
                bless {
                    positions => $row->[4]
                    ,    # Reference to an array of references to hashes...
                    cash       => $row->[3],
                    balance    => $row->[2],
                    name       => $row->[1],
                    sort_code  => $row->[1],
                    account_no => $row->[0],
                    ## parent       => $self,
                    statement => undef,
                },
                "Finance::Bank::Schwab::Account"
            );

            # print join( ',', @$row ), "\n";
        }
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

=head1 NAME

Finance::Bank::Schwab - Check your Charles Schwab accounts from Perl

=head1 SYNOPSIS

  use Finance::Bank::Schwab;
  my @accounts = Finance::Bank::Schwab->check_balance(
      username => "xxxxxxxxxxxx",
      password => "12345",
  );
  
  foreach (@accounts) {
      printf "%20s : %8s / %8s : USD %9.2f USD %9.2f\n",
      $_->name, $_->sort_code, $_->account_no, $_->cash, $_->balance;
      if($_->positions){ 
          foreach my $arrayref ($_->positions) {
              foreach $hashref (@$arrayref){
                  print "\t" . $$hashref{"type"} . "\t" . $$hashref{"symbol"} . "\t" . $$hashref{"quantity"} . " Shares \@\t\$" . $$hashref{"price"} ."\n";
              }
              print "\n";
          } 
      }
  }
  
=head1 DESCRIPTION

This module provides a rudimentary interface to the Charles Schwab site.
You will need either C<Crypt::SSLeay> or C<IO::Socket::SSL> installed 
for HTTPS support to work. C<WWW::Mechanize> is required.  If you encounter
odd errors, install C<Net::SSLeay> and it may resolve itself.

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

  $ac->cash

Return the cash balance as a signed floating point value. This is useful if
the account has margin borrowing as the balance alone doesn't do justice.

  $ac->positions

References an array of hash references. Each hash holds the following:
	      ->symbol		(String)
	      ->quantity	(Signed Float)
	      ->price		(Signed Float)
	      ->type		(Stock/Bond/Cash/Unknown)

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

The ability to retrieve stock/bond/etc positions was contributed by Ryan Clark
<ryan.clark9@gmail.com>.

=head1 AUTHOR

Mark Grimes <mgrimes@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-13 by <mgrimes@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
