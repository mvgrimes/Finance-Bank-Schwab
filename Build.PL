use Module::Build;

my $build = Module::Build->new(
    module_name        => 'Finance::Bank::Schwab',
    license            => 'perl',
    create_readme      => 1,
    ## create_makefile_pl => 'passthrough',
    requires           => {
        'Carp'           => 0,
        'WWW::Mechanize' => 1.00,
        'Crypt::SSLeay'  => 0,
    },
    build_requires => {
        'Test::More' => 0.87,
        'File::Spec' => 0,
    },
    add_to_cleanup => [ 'Finance-Bank-Schwab-*', 'Debian_CPANTS.txt' ],
);
$build->create_build_script;

