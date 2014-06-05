package SysEx;
use strict;
use warnings;

# filenameを開きsysex_msg_str(16進数の'文字列')を返す
#
# @param  string  filename
# @return string  sysex_msg_str
sub read_from_file {
    my $filename = shift;
    my $current_sysex_msg_str;
    my $sysex_msg_str;

    open(my $IN, "<", $filename) or die "$!";
    binmode $IN; # Macでは要らないけどWindowsマシンで動くかもしれないので

    while (read($IN, my $val, 1)){
        # 読み込んだMIDIデータバイトを2文字の16進数文字列に変換
        $current_sysex_msg_str = unpack("H2", $val);

        $sysex_msg_str .= $current_sysex_msg_str;

        # sysexの終了を表すメッセージが来たら読み込み終了
        if (lc($current_sysex_msg_str) eq 'f7'){ last }
    }
    close $IN;
    return $sysex_msg_str;
}

# filenameにsysex_msg_str(16進数の'文字列')を書き込む
#
# @param  string  filename
# @param  string  sysex_msg_str
sub write_to_file {
    my $filename      = shift;
    my $sysex_msg_str = shift;

    open(my $OUT, ">", $filename) or die "$!";
    print $OUT pack("H*", $sysex_msg_str);
    close $OUT;
}

# sysex_msg_strを元にobject_typeを返す
#
# @param  string sysex_msg_str
# @return string
sub get_object_type { return &_common_get($_[0], 5, 5) }

sub get_bank    { return &_common_get($_[0], 6, 6) }
sub get_index   { return &_common_get($_[0], 7, 8) }
sub get_version { return &_common_get($_[0], 9, 9) }
sub get_data    { return &_common_get($_[0], 10, 8935) }

# internal_data_strを元にnameを返す
#
# @param  string internal_data_str
# @return string
sub get_name_by_internal_data_str { return &_common_get($_[0], 0, 23) }

sub get_insert_effect1_by_internal_data_str { return &_common_get($_[0], 88, 96) }


# internal_data_strにnameをセットする
#
# @param  string internal_data_str
# @param  string name_str
# @return string
sub set_name_to_internal_data_str { return &_common_set($_[0], 0, 23, $_[1]) }

sub set_insert_effect1_to_internal_data_str { return &_common_set($_[0], 88, 96, $_[1]) }

sub set_data                      { return &_common_set($_[0], 10, 8935, $_[1]) }



# 7bitのMIDI dataをKronos内部で扱ってる8bitのInternal dataにデコードする
#
# @param  string  data_str(7bitにエンコードされた文字列)
# @return string  internal_data_str
# @see    KRONOS_MIDI_SysEx.txt
sub kronos_data_decode {
    my $data_str = shift;
    my $msb_collect_bin_str; # 7bitに落としこむために8bit時のMSBを寄せ集めたbit列
    my $internal_data_str;   # kronos内部で扱っているInternal data形式

    for (my $data_ofs = 0; $data_ofs < length($data_str) / 2; $data_ofs++) {
        # 1byte(16進文字列を2文字)ずつ読み込み
        my $current_sysex_msg_str = substr($data_str, $data_ofs * 2, 2);

        # $current_sysex_msg_strがMSBを寄せ集めたbit列を表す16進文字列の時
        # ドキュメントの情報では$data_ofsが8の倍数毎に出現する
        if ($data_ofs % 8 == 0){
            # 2進文字列に変換
            $msb_collect_bin_str = &_hex2bin($current_sysex_msg_str);
        } else {
            # 今読み込んでいる'$data_ofs % 8'の'値'に応じて
            # 直近の$msb_collect_bin_strから'n'bit目を取得し$MSBに格納
            my $MSB = substr($msb_collect_bin_str, -1 * $data_ofs % 8, 1);

            my $current_sysex_msg_bin_str = &_hex2bin($current_sysex_msg_str);

            # 先頭1bitを$MSBで置き換える
            substr($current_sysex_msg_bin_str, 0, 1, $MSB);

            $internal_data_str .= &_bin2hex($current_sysex_msg_bin_str);
        }
    }
    return $internal_data_str;
}

# Kronos内部で扱ってる8bitのInternal dataを7bitのMIDI dataをにエンコードする
#
# @param   string  internal_data_str
# @return  string  data_str(7bitにエンコードされた文字列)
# @see     KRONOS_MIDI_SysEx.txt
sub kronos_data_encode {
    my $internal_data_str = shift;
    my $data_str = ''; # return用

    for (my $internal_data_ofs = 0; $internal_data_ofs < length($internal_data_str) / 2; $internal_data_ofs++) {
        # 7バイトごとにmsb_collect_bin_strを付加する
        if ($internal_data_ofs % 7 == 0) {
            my $msb_collect_bin_str = ''; # 7bitに落としこむために8bit時のMSBを寄せ集めたbit列

            # $msb_collect_bin_strを作るために7バイト分先読みする
            for (my $local_ofs = 0; $local_ofs < 7 ; $local_ofs++) {
                # 先読みしようとするオフセットが$internal_data_strを超えないかチェック
                if (($internal_data_ofs + $local_ofs) >= length($internal_data_str) / 2) { last }

                # 先読み
                my $prefetch_str = substr($internal_data_str, ($internal_data_ofs + $local_ofs) * 2, 2);
                my $prefetch_bin_str = &_hex2bin($prefetch_str);

                # 先読みした先頭1bit(1文字)を結合していく(左に)
                $msb_collect_bin_str = substr($prefetch_bin_str, 0, 1) . $msb_collect_bin_str;
            } # for
            # $msb_collect_bin_strを8bitにするため0埋め
            $msb_collect_bin_str = sprintf("%08s",$msb_collect_bin_str);
            # MIDIメッセージとして詰める
            $data_str .= &_bin2hex($msb_collect_bin_str);
        } # if
        # 通所のバイト列は先頭1bitは0にする
        my $current_internal_msg_str = substr($internal_data_str, $internal_data_ofs * 2, 2);
        my $current_internal_msg_bin_str = &_hex2bin($current_internal_msg_str);
        substr($current_internal_msg_bin_str, 0, 1, 0);
        # MIDIメッセージとして詰める
        $data_str .= &_bin2hex($current_internal_msg_bin_str);
    }
    return $data_str;
}

# internal_data_str形式のname_strをASCII形式のoriginal_name_strに変換
#
# @param  string  name_str
# @return string  original_name_str
# @see    KRONOS_MIDI_SysEx.txt
sub name2original_name {
    my $name_str = shift;
    my $original_name_str;
    for(my $ofs = 0; $ofs < length($name_str) / 2; $ofs++){
        my $msg = substr($name_str, $ofs * 2, 2);
        # '00' (NUL文字)がきたら終了
        if ($msg eq '00'){ last };

        $original_name_str .= pack("H2", $msg);
    }
    return $original_name_str;
}

# ASCII形式のoriginal_name_strをinternal_data_str形式のname_strに変換
#
# @param  string  original_name_str
# @return string  name_str
# @see    KRONOS_MIDI_SysEx.txt
sub original_name2name {
    my $original_name_str = shift;
    # バリデーション
    if (length($original_name_str) >= 25){ die }

    # original_name_strからASCIIコード(16進文字列)に変換する
    my $name_str = unpack("H*", $original_name_str);

    # 24バイト(48文字)に満たない場合は0パディング(古典的手法)
    foreach (length($name_str)+1..48){ $name_str .= '0' }
    return $name_str;
}

# @param  string  insert_effect_str
# @return int     effect_type_dec_str
sub insert_effect2effect_type {
    my $effect_type_str = &_common_get($_[0], 0, 0);
    # 10進にして返す
    return hex($effect_type_str);
}

# @param  string  insert_effect_str
# @param  int     effect_type_dec_str
# @return string  insert_effect_str
sub effect_type2insert_effect {
    my $insert_effect_str   = shift;
    my $effect_type_dec_str = shift;

    # 2桁の16進数文字列にする
    my $effect_type_str = sprintf("%02x", $effect_type_dec_str);

    return &_common_set($insert_effect_str, 0, 0, $effect_type_str);
}

# debug
sub print_msg {
    my $str      = shift;
    my $if_ascii = shift;

    for(my $ofs = 0;$ofs < length($str) / 2; $ofs++){
        my $msg = substr($str, $ofs * 2, 2);
        print    "OFS = ".$ofs;
        print " | MSG = ".$msg;
        print " | MSG_DEC = ".hex($msg);
        print " | ASCII = ".chr(hex($msg)) if ($if_ascii);
        print "\n";
    }
}

# strから特定のofsのメッセージを取得する
#
# @param  string  sysex_msg_str
# @param  integer start_ofs(0スタート)
# @param  integer end_ofs(0スタート)
# @return string  sysex_msg_str(切り出したsysex_msg_str)
#
# 例
# $str = 'F0423068730143000003'から
# 014300を取得する場合
# _common_get($str, 5 ,7);
sub _common_get {
    my $sysex_msg_str = shift;
    my $start_ofs     = shift;
    my $end_ofs       = shift;
    return substr($sysex_msg_str, $start_ofs * 2, (1 + $end_ofs - $start_ofs) * 2);
}

# strを特定のofsに対し任意文字列で置き換える
#
# @param  string  str
# @param  integer start_ofs(0スタート)
# @param  integer end_ofs(0スタート)
# @param  string  replacement
# @return string  str(置き換え後の)
sub _common_set {
    my $str         = shift;
    my $start_ofs   = shift;
    my $end_ofs     = shift;
    my $replacement = shift;

    substr($str, $start_ofs * 2, (1 + $end_ofs - $start_ofs) * 2, $replacement);
    return $str;
}

sub _hex2bin { return unpack('B8', pack('H2', $_[0])) }
sub _bin2hex { return unpack('H2', pack('B8', $_[0])) }

1;
