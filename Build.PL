use Module::Build;

my $build = Module::Build->new(
    module_name   => 'Finance::Bank::Schwab',
    license       => 'perl',
    create_readme => 1,
    ## create_makefile_pl => 'passthrough',
    requires => {
        'Carp'                 => 0,
        'WWW::Mechanize'       => 1.00,
        'HTML::TableExtract'   => 2,
        'Crypt::SSLeay'        => 0,
        'LWP::Protocol::https' => 0,
    },
    build_requires => {
        'Test::More' => 0.87,
        'File::Spec' => 0,
    },
    add_to_cleanup => [ 'Finance-Bank-Schwab-*', 'Debian_CPANTS.txt' ],
    meta_merge     => {
        resources => {
            bugtracker =>
              'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Finance-Bank-Schwab',
            repository => 'http://github.com/mvgrimes/Finance-Bank-Schwab'
        }
    },
);
$build->create_build_script;

