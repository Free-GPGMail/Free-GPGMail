<?php
/**
 * Generate test case overview for the GPGMail wiki.
 *
 * @author  Alex
 * @version 2011-08-13
 */

/* -------------------------------------------------------------------------- */
define("STATUS_TBT","TBT");
define("COLOR_TBT","orange");
define("STATUS_INV","INV");
define("COLOR_INV","gray");
define("STATUS_OK","OK");
define("COLOR_OK","green");
define("STATUS_NYI","NYI");
define("COLOR_NYI","red");
define("STATUS_ISSUE","#xxx");
define("COLOR_ISSUE","blue");
define("SEND",0);
define("RECV",1);
define("COMMENT",2);
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
$openpgp = array ("ME","MS","MB","IE","IS","IB");
$smime = array ("NN","EE","SS","BB");
$message = array ("VT","MT"); // "VH", "MH"
$attachment = array ("NA","VA","MA");
$receiver = array ("S","M","B");
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
$result["IB"]["BB"]["VT"]["NA"]["S"][RECV] = "#286";
$result["IB"]["NN"]["MT"]["MA"]["S"][RECV] = STATUS_OK;
$result["IB"]["NN"]["MT"]["NA"]["S"][RECV] = STATUS_OK;
$result["IB"]["NN"]["VT"]["MA"]["S"][RECV] = "#279";
$result["IB"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["IB"]["NN"]["VT"]["VA"]["S"][RECV] = "#239";
$result["IE"]["NN"]["MT"]["MA"]["S"][RECV] = STATUS_OK;
$result["IE"]["NN"]["MT"]["VA"]["S"][RECV] = STATUS_OK;
$result["IE"]["NN"]["VT"]["MA"]["S"][RECV] = "#280";
$result["IE"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["IE"]["NN"]["VT"]["VA"]["S"][RECV] = "#280";
$result["IS"]["NN"]["MT"]["MA"]["S"][RECV] = "#281";
$result["IS"]["NN"]["MT"]["NA"]["S"][RECV] = STATUS_OK;
$result["IS"]["NN"]["VT"]["MA"]["S"][RECV] = "#283";
$result["IS"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["IS"]["NN"]["VT"]["VA"]["S"][RECV] = "#266";
$result["IS"]["SS"]["VT"]["NA"]["S"][RECV] = "#244";
$result["MB"]["NN"]["MT"]["MA"]["S"][RECV] = STATUS_OK;
$result["MB"]["NN"]["MT"]["NA"]["S"][RECV] = STATUS_OK;
$result["MB"]["NN"]["VT"]["MA"]["S"][RECV] = STATUS_OK;
$result["MB"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["MB"]["NN"]["VT"]["NA"]["S"][SEND] = STATUS_OK;
$result["MB"]["NN"]["VT"]["VA"]["S"][RECV] = STATUS_OK;
$result["MB"]["NN"]["VT"]["VA"]["S"][SEND] = STATUS_OK;
$result["ME"]["NN"]["MT"]["MA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["MT"]["NA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["MA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["S"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["VA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["VA"]["S"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["S"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["M"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["M"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["B"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["NA"]["B"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["VA"]["S"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["VA"]["S"][RECV] = STATUS_OK;
$result["ME"]["NN"]["VT"]["VA"]["M"][SEND] = STATUS_OK;
$result["ME"]["NN"]["VT"]["VA"]["M"][RECV] = STATUS_OK;
$result["MS"]["NN"]["MT"]["MA"]["S"][RECV] = STATUS_OK;
$result["MS"]["NN"]["MT"]["NA"]["S"][RECV] = STATUS_OK;
$result["MS"]["NN"]["VT"]["MA"]["S"][RECV] = STATUS_OK;
$result["MS"]["NN"]["VT"]["NA"]["S"][RECV] = STATUS_OK;
$result["MS"]["NN"]["VT"]["NA"]["S"][SEND] = STATUS_OK;
$result["MS"]["NN"]["VT"]["VA"]["S"][RECV] = STATUS_OK;
$result["MS"]["NN"]["VT"]["VA"]["S"][SEND] = STATUS_OK;
$result["MS"]["NN"]["VT"]["NA"]["M"][RECV] = STATUS_OK;
$result["MS"]["NN"]["VT"]["NA"]["M"][SEND] = STATUS_OK;
/* -------------------------------------------------------------------------- */

function printRow($a, $b, $c, $d, $e, $i, $stats, $result) {
    /* config --------------------------------------------------------------- */
    $template = "|%04d|%s/%s/%s/%s/%s|<font color='%s'>%s</font>|<font color='%s'>%s</font>|%s|\n";
    /* ---------------------------------------------------------------------- */

    /* results -------------------------------------------------------------- */
    $send_status = $result[$a][$b][$c][$d][$e][SEND] ?
                   $result[$a][$b][$c][$d][$e][SEND] :
                   STATUS_TBT;
    $recv_status = $result[$a][$b][$c][$d][$e][RECV] ?
                   $result[$a][$b][$c][$d][$e][RECV] :
                   STATUS_TBT;
    $comment = $result[$a][$b][$c][$d][$e][COMMENT] ?
                   $result[$a][$b][$c][$d][$e][COMMENT] :
                   "";
    /* ---------------------------------------------------------------------- */

    /* generic rules -------------------------------------------------------- */
    if ("NN" == $b && "VT" == $c && ("NA" == $d || "VA" == $d)) {
        $comment = "Important and simple use case.";
    }
    if ("M" == substr($a, 0, 1) && "NN" != $b) {
        $send_status = STATUS_INV;
        $recv_status = STATUS_INV;
        $comment = "Can't use MIME twice";
    }
    if ("NN" == $a) {
        $send_status = STATUS_INV;
        $recv_status = STATUS_INV;
        $comment .= " (No testing needed)";
    }
    if ("I" == substr($a, 0, 1)) {
        $send_status = STATUS_INV;
        $comment .= " (Sending PGP/Inline not supported)";
    }
    /* ---------------------------------------------------------------------- */

    /* set the color -------------------------------------------------------- */
    if (STATUS_TBT == $send_status) {$send_color=COLOR_TBT; ++$stats[STATUS_TBT];}
    if (STATUS_TBT == $recv_status) {$recv_color=COLOR_TBT; ++$stats[STATUS_TBT];}
    if (STATUS_INV == $send_status) {$send_color=COLOR_INV; ++$stats[STATUS_INV];}
    if (STATUS_INV == $recv_status) {$recv_color=COLOR_INV; ++$stats[STATUS_INV];}
    if (STATUS_OK == $send_status) {$send_color=COLOR_OK; ++$stats[STATUS_OK];}
    if (STATUS_OK == $recv_status) {$recv_color=COLOR_OK; ++$stats[STATUS_OK];}
    if (STATUS_NYI == $send_status) {$send_color=COLOR_NYI; ++$stats[STATUS_NYI];}
    if (STATUS_NYI == $recv_status) {$recv_color=COLOR_NYI; ++$stats[STATUS_NYI];}
    if ("#" == substr($send_status, 0, 1)) {
        $nr = substr($send_status, 1);
        $send_status = "<a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/$nr'>#$nr</a>";
        $send_color=COLOR_ISSUE;
        ++$stats[STATUS_ISSUE];
    }
    if ("#" == substr($recv_status, 0, 1)) {
        $nr = substr($recv_status, 1);
        $recv_status = "<a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/$nr'>#$nr</a>";
        $recv_color=COLOR_ISSUE;
        ++$stats[STATUS_ISSUE];
    }
    /* ---------------------------------------------------------------------- */


    /* ---------------------------------------------------------------------- */
    if (! (STATUS_INV == $send_status && STATUS_INV == $recv_status)) {
        if (STATUS_INV != $send_status) ++$j;
        if (STATUS_INV != $recv_status) ++$j;
        ++$i;
        printf ($template, $i, $a, $b, $c, $d, $e,
                $send_color, $send_status, $recv_color, $recv_status, $comment);
    }
    /* ---------------------------------------------------------------------- */
}

/* main --------------------------------------------------------------------- */
$i = 0;
$stats = array();
foreach ($openpgp as $a) {
    foreach ($smime as $b) {
        foreach ($message as $c) {
            foreach ($attachment as $d) {
                foreach ($receiver as $e) {
                    printRow($a, $b, $c, $d, $e, &$i, &$stats, &$result);
                }
            }
        }
    }
}
/* -------------------------------------------------------------------------- */

echo "\n";
echo " * Seems to work (<font color='". COLOR_OK ."'>" . STATUS_OK ."</font>): ". $stats[STATUS_OK] ."\n";
echo " * To be tested (<font color='". COLOR_TBT ."'>" . STATUS_TBT ."</font>): ". $stats[STATUS_TBT] ."\n";
echo " * Has issues (<font color='". COLOR_ISSUE ."'>" . STATUS_ISSUE ."</font>): ". $stats[STATUS_ISSUE] ."\n";
//echo " * Not yet implemented (<font color='". COLOR_NYI ."'>" . STATUS_NYI ."</font>): ". $stats[STATUS_NYI] ."\n";
echo " * Combination not possible, out of scope or no testing needed (<font color='". COLOR_INV ."'>" . STATUS_INV ."</font>): ". $stats[STATUS_INV] ."\n";

?>
