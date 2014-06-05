#!/usr/bin/perl
use strict;
use warnings;
use lib::SysEx;
use feature 'say';

# syxファイル読み込み
my $filename = $ARGV[0];
my $sysex_msg_str = SysEx::read_from_file($filename);

say "object_type = ".SysEx::get_object_type($sysex_msg_str);
say "bank        = ".SysEx::get_bank($sysex_msg_str);
say "index       = ".SysEx::get_index($sysex_msg_str);
say "version     = ".SysEx::get_version($sysex_msg_str);

# sysexメッセージからdata部分取得
my $data_str = SysEx::get_data($sysex_msg_str);

# data_str(7bit)を$internal_data_str(8bit)にデコード
my $internal_data_str = SysEx::kronos_data_decode($data_str);

# internal_data_strからname(16進数文字列を取り出し)
my $name_str = SysEx::get_name_by_internal_data_str($internal_data_str);

# internal_data_str形式から表示名を取得
my $original_name_str = SysEx::name2original_name($name_str);

say "original_name_str = ".$original_name_str;

# internal_data_str形式からinsert_effect1情報取得
my $insert_effect1_str = SysEx::get_insert_effect1_by_internal_data_str($internal_data_str);

# insert_effect_strからeffect_type_dec_str(0-185)取得
my $effect_type_dec_str = SysEx::insert_effect2effect_type($insert_effect1_str);

say "effect_type_dec_str = ".$effect_type_dec_str;

##################ここまで読み出し

##################ここから書き込み

# コンビネーションの名前を編集
$original_name_str .= '_MOD';

# original_name_strをinternal_data_str形式にする
$name_str = SysEx::original_name2name($original_name_str);

# internal_data_strにnameをセット
$internal_data_str = SysEx::set_name_to_internal_data_str($internal_data_str, $name_str);

# インサートエフェクト1のeffect_typeを140でセット
$insert_effect1_str = SysEx::effect_type2insert_effect($insert_effect1_str, 140);

# internal_data_strにinsert_effect1をセット
$internal_data_str = SysEx::set_insert_effect1_to_internal_data_str($internal_data_str, $insert_effect1_str);

# data部分をエンコード
$data_str = SysEx::kronos_data_encode($internal_data_str);

# sysexメッセージにdata部分をセット
$sysex_msg_str = SysEx::set_data($sysex_msg_str, $data_str);

# ファイルに書き出し
$filename =~ s/.syx$/_mod.syx/;
SysEx::write_to_file($filename, $sysex_msg_str);

say "Done";
