#!/bin/sh
#
# Copyright (c) 2005 Junio C Hamano
#

test_description='Break and then rename

We have two very different files, file0 and file1, registered in a tree.

We update file1 so drastically that it is more similar to file0, and
then remove file0.  With -B, changes to file1 should be broken into
separate delete and create, resulting in removal of file0, removal of
original file1 and creation of completely rewritten file1.  The latter
two are then merged back into a single "complete rewrite".

Further, with -B and -M together, these three modifications should
turn into rename-edit of file0 into file1.

Starting from the same two files in the tree, we swap file0 and file1.
With -B, this should be detected as two complete rewrites.

Further, with -B and -M together, these should turn into two renames.
'
. ./test-lib.sh
. "$TEST_DIRECTORY"/diff-lib.sh ;# test-lib chdir's into trash

test_expect_success setup '
	tr -d "\015" <"$TEST_DIRECTORY"/diff-lib/README >file0 &&
	tr -d "\015" <"$TEST_DIRECTORY"/diff-lib/COPYING >file1 &&
	git update-index --add file0 file1 &&
	git tag reference $(git write-tree)
'

test_expect_success 'change file1 with copy-edit of file0 and remove file0' '
	sed -e "s/git/GIT/" file0 >file1 &&
	rm -f file0 &&
	git update-index --remove file0 file1
'

test_expect_success 'run diff with -B (#1)' '
	git diff-index -B --cached reference >current &&
	cat >expect <<-\EOF &&
	:100644 000000 548142c327a6790ff8821d67c2ee1eff7a656b52 0000000000000000000000000000000000000000 D	file0
	:100644 100644 6ff87c4664981e4397625791c8ea3bbb5f2279a3 2fbedd0b5d4b8126e4750c3bee305e8ff79f80ec M100	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'run diff with -B and -M (#2)' '
	git diff-index -B -M reference >current &&
	cat >expect <<-\EOF &&
	:100644 100644 548142c327a6790ff8821d67c2ee1eff7a656b52 2fbedd0b5d4b8126e4750c3bee305e8ff79f80ec R100	file0	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'swap file0 and file1' '
	rm -f file0 file1 &&
	git read-tree -m reference &&
	git checkout-index -f -u -a &&
	mv file0 tmp &&
	mv file1 file0 &&
	mv tmp file1 &&
	git update-index file0 file1
'

test_expect_success 'run diff with -B (#3)' '
	git diff-index -B reference >current &&
	cat >expect <<-\EOF &&
	:100644 100644 548142c327a6790ff8821d67c2ee1eff7a656b52 6ff87c4664981e4397625791c8ea3bbb5f2279a3 M100	file0
	:100644 100644 6ff87c4664981e4397625791c8ea3bbb5f2279a3 548142c327a6790ff8821d67c2ee1eff7a656b52 M100	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'run diff with -B and -M (#4)' '
	git diff-index -B -M reference >current &&
	cat >expect <<-\EOF &&
	:100644 100644 6ff87c4664981e4397625791c8ea3bbb5f2279a3 6ff87c4664981e4397625791c8ea3bbb5f2279a3 R100	file1	file0
	:100644 100644 548142c327a6790ff8821d67c2ee1eff7a656b52 548142c327a6790ff8821d67c2ee1eff7a656b52 R100	file0	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'make file0 into something completely different' '
	rm -f file0 &&
	test_ln_s_add frotz file0 &&
	git update-index file1
'

test_expect_success 'run diff with -B (#5)' '
	git diff-index -B reference >current &&
	cat >expect <<-\EOF &&
	:100644 120000 548142c327a6790ff8821d67c2ee1eff7a656b52 67be421f88824578857624f7b3dc75e99a8a1481 T	file0
	:100644 100644 6ff87c4664981e4397625791c8ea3bbb5f2279a3 548142c327a6790ff8821d67c2ee1eff7a656b52 M100	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'run diff with -B -M (#6)' '
	git diff-index -B -M reference >current &&

	# file0 changed from regular to symlink.  file1 is the same as the preimage
	# of file0.  Because the change does not make file0 disappear, file1 is
	# denoted as a copy of file0
	cat >expect <<-\EOF &&
	:100644 120000 548142c327a6790ff8821d67c2ee1eff7a656b52 67be421f88824578857624f7b3dc75e99a8a1481 T	file0
	:100644 100644 548142c327a6790ff8821d67c2ee1eff7a656b52 548142c327a6790ff8821d67c2ee1eff7a656b52 C	file0	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'run diff with -M (#7)' '
	git diff-index -M reference >current &&

	# This should not mistake file0 as the copy source of new file1
	# due to type differences.
	cat >expect <<-\EOF &&
	:100644 120000 548142c327a6790ff8821d67c2ee1eff7a656b52 67be421f88824578857624f7b3dc75e99a8a1481 T	file0
	:100644 100644 6ff87c4664981e4397625791c8ea3bbb5f2279a3 548142c327a6790ff8821d67c2ee1eff7a656b52 M	file1
	EOF
	compare_diff_raw expect current
'

test_expect_success 'file1 edited to look like file0 and file0 rename-edited to file2' '
	rm -f file0 file1 &&
	git read-tree -m reference &&
	git checkout-index -f -u -a &&
	sed -e "s/git/GIT/" file0 >file1 &&
	sed -e "s/git/GET/" file0 >file2 &&
	rm -f file0 &&
	git update-index --add --remove file0 file1 file2
'

test_expect_success 'run diff with -B (#8)' '
	git diff-index -B reference >current &&
	cat >expect <<-\EOF &&
	:100644 000000 548142c327a6790ff8821d67c2ee1eff7a656b52 0000000000000000000000000000000000000000 D	file0
	:100644 100644 6ff87c4664981e4397625791c8ea3bbb5f2279a3 2fbedd0b5d4b8126e4750c3bee305e8ff79f80ec M100	file1
	:000000 100644 0000000000000000000000000000000000000000 69a939f651686f56322566e2fd76715947a24162 A	file2
	EOF
	compare_diff_raw expect current
'

test_expect_success 'run diff with -B -C (#9)' '
	git diff-index -B -C reference >current &&
	cat >expect <<-\EOF &&
	:100644 100644 548142c327a6790ff8821d67c2ee1eff7a656b52 2fbedd0b5d4b8126e4750c3bee305e8ff79f80ec C095	file0	file1
	:100644 100644 548142c327a6790ff8821d67c2ee1eff7a656b52 69a939f651686f56322566e2fd76715947a24162 R095	file0	file2
	EOF
	compare_diff_raw expect current
'

test_done
