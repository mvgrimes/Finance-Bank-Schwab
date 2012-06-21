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
use HTML::TableExtract;

our $VERSION = '1.22';

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
        headers   => [ 'Account', 'Name', '(?:Value|Available\s+Balance)' ],
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

            # Simple regex to strip html from cells
            $row->[0] =~ s{<[^>]*>}{}mg;
            $row->[1] =~ s{<[^>]*>}{}mg;
            $row->[2] =~ s{<[^>]*>}{}mg;

            $_ =~ s{^\s*|\s*$}{}g for @$row;    # Trim whitespace
            $row->[0] =~ s{^([\d.-]+).*$}{$1}s; # Strip all but num from name
            $row->[2] =~ s/[\$,]//xg;           # Remove $ and , from value

            push @accounts, (
                bless {
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

This module provides a rudimentary interface to the Charles Schwab site.
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
