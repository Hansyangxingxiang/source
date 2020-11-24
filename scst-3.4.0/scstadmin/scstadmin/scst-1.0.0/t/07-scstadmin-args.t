#!perl

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use Test;

my $testdir;
my $scstadmin;
my $redirect_file;
my $redirect;

BEGIN {
    $redirect_file = "/tmp/scstadmin-test-07-output.txt";
    unlink($redirect_file);
    $testdir = dirname(abs_path($0));
    my $scstadmin_pm_dir = dirname($testdir);
    my $scstadmin_dir = dirname($scstadmin_pm_dir);
    $scstadmin = File::Spec->catfile($scstadmin_dir, "scstadmin");
    unless(grep /blib/, @INC) {
	unshift(@INC, File::Spec->catdir($scstadmin_pm_dir, "lib"));
    }
    plan tests => 59;
}

use Data::Dumper;
use SCST::SCST;
use File::Temp qw/tempfile/;

sub setup {
    my $SCST = shift;

    my ($drivers, $errorString) = $SCST->drivers();
    my %drivers = map { $_ => 1 } @{$drivers};
    ok(exists($drivers{'scst_local'}));
    ok(system("dd if=/dev/zero of=/dev/scstadmin-regression-test-vdisk bs=1M count=1 >/dev/null 2>&1"), 0);
}

sub teardown {
    system("rm -f /dev/scstadmin-regression-test-vdisk");
}

sub attributeTest {
    my $expected = shift;
    my $tmpfilename1 = File::Spec->catfile(File::Spec->tmpdir(),
					   "scstadmin-test-07-$$-1");
    my $tmpfilename2 = File::Spec->catfile(File::Spec->tmpdir(),
					   "scstadmin-test-07-$$-2");
    my $diff         = File::Spec->catfile(File::Spec->tmpdir(),
					   "scstadmin-test-07-$$-diff");

    ok(system("$scstadmin -clear_config -force -noprompt -no_lip $redirect"), 0);
    ok(system("$scstadmin -open_dev nodev -handler vdisk_nullio -attributes dummy=1 $redirect"), 0);
    ok(system("$scstadmin -open_dev disk0 -handler vdisk_fileio -attributes filename=/dev/scstadmin-regression-test-vdisk,read_only=1 $redirect"), 0);
    ok(system("$scstadmin -open_dev disk1 -handler vdisk_fileio -attributes filename=/dev/scstadmin-regression-test-vdisk,nv_cache=1 $redirect"), 0);
    ok(system("$scstadmin -driver scst_local -add_target local $redirect"), 0);
    ok(system("$scstadmin -driver scst_local -target local " .
	   "-add_lun 0 -device nodev $redirect"), 0);
    ok(system("$scstadmin -driver scst_local -target local -add_group ig " .
	   "$redirect"), 0);
    ok(system("$scstadmin -driver scst_local -target local -group ig " .
	   "-add_init ini1 $redirect"), 0);
    ok(system("$scstadmin -driver scst_local -target local -group ig " .
	   "-add_init ini2 $redirect"), 0);
    ok(system("$scstadmin -driver scst_local -target local -group ig " .
	   "-add_lun 0 -device disk0 $redirect"), 0);
    ok(system("$scstadmin -driver scst_local -target local -group ig " .
	   "-add_lun 1 -device disk1 $redirect"), 0);

    ok(system("$scstadmin -add_dgrp dgroup1 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp tgroup1 -dev_group dgroup1 $redirect"), 0);
    ok(system("$scstadmin -noprompt -set_tgrp_attr tgroup1 -dev_group dgroup1 -attributes group_id=256 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp_tgt local -dev_group dgroup1 -tgt_group tgroup1 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp tgroup2 -dev_group dgroup1 $redirect"), 0);
    ok(system("$scstadmin -noprompt -set_tgrp_attr tgroup2 -dev_group dgroup1 -attributes group_id=257 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp_tgt remote -dev_group dgroup1 -tgt_group tgroup2 $redirect"), 0);
    ok(system("{ echo 11 > /sys/kernel/scst_tgt/device_groups/dgroup1/target_groups/tgroup2/remote/rel_tgt_id; } $redirect"), 0);

    ok(system("$scstadmin -add_dgrp dgroup2 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp tgroup1 -dev_group dgroup2 $redirect"), 0);
    ok(system("$scstadmin -noprompt -set_tgrp_attr tgroup1 -dev_group dgroup2 -attributes group_id=258 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp_tgt local -dev_group dgroup2 -tgt_group tgroup1 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp tgroup2 -dev_group dgroup2 $redirect"), 0);
    ok(system("$scstadmin -noprompt -set_tgrp_attr tgroup2 -dev_group dgroup2 -attributes group_id=259 $redirect"), 0);
    ok(system("$scstadmin -noprompt -set_tgrp_attr tgroup1 -dev_group dgroup2 -attributes rel_tgt_id=2 $redirect"), 0);
    ok(system("$scstadmin -add_tgrp_tgt remote -dev_group dgroup2 -tgt_group tgroup2 $redirect"), 0);
    ok(system("{ echo 12 > /sys/kernel/scst_tgt/device_groups/dgroup2/target_groups/tgroup2/remote/rel_tgt_id; } $redirect"), 0);

    ok(system("$scstadmin -write_config $tmpfilename1 >/dev/null"), 0);

    # Keep only the scst_local target driver information.
    my $cmd = "gawk 'BEGIN { t = 0 } /^# Automatically generated by SCST Configurator v/ {" .
	'$0 = "# Automatically generated by SCST Configurator v..." } ' .
	'/^TARGET_DRIVER.*{$/ { if (match($0, "TARGET_DRIVER ([^ ]*) {", d) && d[1] != "scst_local") t = 1 } ' .
	'/^}$/ { if (t == 1) t = 2 } ' .
	'/^$/ { if (t == 2) { t = 3 } } ' .
	'/^./ { if (t == 3) { t = 0 } } ' .
	'{ if (t == 0) print }' .
	"' <$tmpfilename1 >$tmpfilename2";
    ok(system($cmd), 0);
    my $compare_result = system("diff -u $tmpfilename2 $expected >$diff");
    ok($compare_result, 0);
    if ($compare_result == 0) {
	unlink($diff);
	unlink($tmpfilename2);
	unlink($tmpfilename1);
    }
}

# Run shell command $1 and return what it wrote to stdout and stderr as a
# string.
sub run {
    my ($cmd) = @_;
    my $tmpfile = File::Spec->catfile(File::Spec->tmpdir(),
				      "scstadmin-test-07-$$-3");
    my $res;
    my $rc;

    $rc = system("$cmd >$tmpfile 2>&1");
    if (!open(my $file, $tmpfile)) {
	$res = "failed to read $tmpfile";
    } else {
	local $/ = undef;
	binmode $file;
	$res = <$file>;
	if (!defined($res)) {
	    $res = "";
	}
	close $file;
    }
    unlink($tmpfile);
    return $res;
}

# Trigger the scstadmin prompt() subroutine.
sub testPrompt {
    my $result;

    $result = <<'EOS';

Collecting current configuration: done.

Performing this action may result in lost or corrupt data, are you sure you wish to continue (y/[n]) ? Aborting action.

All done.
EOS
    ok(run("$scstadmin -clear_config -force </dev/null"), $result);
}

# Test the scstadmin -list_* options.
sub listTest {
    my $result;

    $result = <<'EOS';

Collecting current configuration: done.

	Handler
	-------------
	vcdrom
	vdisk_blockio
	vdisk_fileio
	vdisk_nullio

All done.
EOS
    ok(run("$scstadmin -list_handler"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Handler           Device
	-----------------------
	vcdrom           -    
	vdisk_blockio    -    
	vdisk_fileio     disk0
	                 disk1
	vdisk_nullio     nodev

All done.
EOS
    ok(run("$scstadmin -list_device"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value                                    Writable      KEY
	------------------------------------------------------------------------
	filename      /dev/scstadmin-regression-test-vdisk     Yes           Yes
	read_only     1                                        No            Yes
	size          1048576                                  No            Yes

All done.
EOS
    ok(run("$scstadmin -list_device disk0"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Device Group
	------------
	dgroup1

	dgroup2


All done.
EOS
    ok(run("$scstadmin -list_dgrp"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Targets
	-------

All done.
EOS
    ok(run("$scstadmin -list_tgrp tgrp -dev_group dgroup1"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Driver
	------------
	copy_manager
	ib_srpt
	iscsi
	scst_local

All done.
EOS
    ok(run("$scstadmin -list_driver"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Driver       Target          
	-----------------------------
	copy_manager copy_manager_tgt
	scst_local   local           

All done.
EOS
    ok(run("$scstadmin -list_target"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

Driver: copy_manager
Target: copy_manager_tgt

Assigned LUNs:

	LUN  Device
	----------
	10   disk1
	8    nodev
	9    disk0

Driver: scst_local
Target: local

Assigned LUNs:

	LUN  Device
	----------
	0    nodev

Group: ig

Assigned LUNs:

	LUN  Device
	----------
	0    disk0
	1    disk1

Assigned Initiators:

	Initiator
	----
	ini1
	ini2



All done.
EOS
    ok(run("$scstadmin -list_group"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

All done.
EOS
    ok(run("$scstadmin -list_scst_attr"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

	Device CREATE attributes available
	----------------------------------
	tst

All done.
EOS
    ok(run("$scstadmin -list_hnd_attr vcdrom"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

	Device CREATE attributes available
	----------------------------------
	active
	bind_alua_state
	blocksize
	cluster_mode
	dif_filename
	dif_mode
	dif_static_app_tag
	dif_type
	filename
	numa_node_id
	nv_cache
	read_only
	removable
	rotational
	thin_provisioned
	tst
	write_through

All done.
EOS
    ok(run("$scstadmin -list_hnd_attr vdisk_blockio"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

	Device CREATE attributes available
	----------------------------------
	async
	blocksize
	cluster_mode
	dif_filename
	dif_mode
	dif_static_app_tag
	dif_type
	filename
	numa_node_id
	nv_cache
	o_direct
	read_only
	removable
	rotational
	thin_provisioned
	tst
	write_through
	zero_copy

All done.
EOS
    ok(run("$scstadmin -list_hnd_attr vdisk_fileio"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

	Device CREATE attributes available
	----------------------------------
	blocksize
	cluster_mode
	dif_mode
	dif_static_app_tag
	dif_type
	dummy
	numa_node_id
	read_only
	removable
	rotational
	size
	size_mb
	tst

All done.
EOS
    ok(run("$scstadmin -list_hnd_attr vdisk_nullio"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value                                    Writable      KEY
	------------------------------------------------------------------------
	filename      /dev/scstadmin-regression-test-vdisk     Yes           Yes
	read_only     1                                        No            Yes
	size          1048576                                  No            Yes

All done.
EOS
    ok(run("$scstadmin -list_dev_attr disk0"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value                                    Writable      KEY
	------------------------------------------------------------------------
	filename      /dev/scstadmin-regression-test-vdisk     Yes           Yes
	nv_cache      1                                        No            Yes
	size          1048576                                  No            Yes

All done.
EOS
    ok(run("$scstadmin -list_dev_attr disk1"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

All done.
EOS
    ok(run("$scstadmin -list_drv_attr ib_srpt"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value      Writable      KEY
	------------------------------------------
	group_id      256        Yes           Yes
	state         active     Yes           Yes

All done.
EOS
    ok(run("$scstadmin -list_tgrp_attr tgroup1 -dev_group dgroup1"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

All done.
EOS
    ok(run("$scstadmin -list_ttgt_attr local -tgt_group tgroup1 -dev_group dgroup1"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

	LUN CREATE attributes available
	-------------------------------
	read_only

All done.
EOS
    ok(run("$scstadmin -list_tgt_attr local -driver scst_local"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

	LUN CREATE attributes available
	-------------------------------
	read_only

All done.
EOS
    ok(run("$scstadmin -list_grp_attr ig -driver scst_local -target local -group ip"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

All done.
EOS
    ok(run("$scstadmin -list_lun_attr 0 -driver scst_local -target local"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

	Attribute     Value     Writable      KEY
	-----------------------------------------
	(none)

All done.
EOS
    ok(run("$scstadmin -list_lun_attr 1 -driver scst_local -target local -group ig"), $result);

    $result = <<'EOS';

Collecting current configuration: done.



WARNING: Received the following error:

	initiatorAttributes(): Unable to read directory '/sys/kernel/scst_tgt/targets/scst_local/local/ini_groups/ig/initiators/ini1': Bad file descriptor


All done.
EOS
    ok(run("$scstadmin -list_init_attr ini1 -driver scst_local -target local -group ig"), $result);

    $result = <<'EOS';

Collecting current configuration: done.



WARNING: Received the following error:

	initiatorAttributes(): Unable to read directory '/sys/kernel/scst_tgt/targets/scst_local/local/ini_groups/ig/initiators/ini2': Bad file descriptor


All done.
EOS
    ok(run("$scstadmin -list_init_attr ini2 -driver scst_local -target local -group ig"), $result);

    $result = <<'EOS';

Collecting current configuration: done.

Driver/Target: copy_manager/copy_manager_tgt

	Session: copy_manager_sess

	Attribute                     Value                 Writable      KEY
	---------------------------------------------------------------------
	active_commands               0                     Yes           No 
	bidi_cmd_count                0                     Yes           No 
	bidi_io_count_kb              0                     Yes           No 
	bidi_unaligned_cmd_count      0                     Yes           No 
	commands                      0                     Yes           No 
	dif_checks_failed             	app	ref	guard        Yes           No 
	initiator_name                copy_manager_sess     Yes           No 
	none_cmd_count                0                     Yes           No 
	read_cmd_count                11                    Yes           No 
	read_io_count_kb              44                    Yes           No 
	read_unaligned_cmd_count      0                     Yes           No 
	unknown_cmd_count             0                     Yes           No 
	write_cmd_count               0                     Yes           No 
	write_io_count_kb             0                     Yes           No 
	write_unaligned_cmd_count     0                     Yes           No 

Driver/Target: scst_local/local

	(no sessions)


All done.
EOS
    ok(run("$scstadmin -list_sessions"), $result);
}

my $_DEBUG_ = 0;
if ($_DEBUG_) {
    $redirect = ">>$redirect_file 2>&1";
    open(my $logfile, '>>', $redirect_file);
    select $logfile;
} else {
    $redirect = ">/dev/null";
}

my $SCST = eval { new SCST::SCST($_DEBUG_) };
die("Creation of SCST object failed") if (!defined($SCST));

setup($SCST);

attributeTest(File::Spec->catfile($testdir, "07-result.conf"));

testPrompt();

listTest();

teardown();
