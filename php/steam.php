<?php
// simple steam profile -> json retrieval script
// [foo] bar <foobarhl@gmail.com>

function steam32to64($steamid)
{

  $split = explode(":", $steamid); // STEAM_?:?:??????? format

  $x = substr($split[0], 6, 1);
  $y = $split[1];
  $z = $split[2];

  $w = ($z * 2) + 0x0110000100000000 + $y;
  return($w);

}

function isValidSteamID($steamid)
{
 if(strlen(trim($steamid)) != 0)
 {
    $regex = "/^STEAM_0:[01]:[0-9]{7,8}$/";
    if(!preg_match($regex, $steamid))
    {
      return(FALSE);
    } else {
     return(TRUE);
    }
 }
   
}

function jsonRemoveUnicodeSequences($struct) {
   return preg_replace("/\\\\u([a-f0-9]{4})/e", "iconv('UCS-4LE','UTF-8',pack('V', hexdec('U$1')))", json_encode($struct));
}
   
    
if(!isset($_REQUEST['s'])){
  exit;
}

if(isset($_REQUEST['cx'])){ 
 $cx = intval($_REQUEST['cx']);
} else {
 $cx=-1;
}
$steamID = $_REQUEST['s'];
if(!isValidSteamID($steamID)){
 exit;
}

$s64 = steam32to64($steamID);

$url="http://steamcommunity.com/profiles/".$s64."/?xml=1";
$xml=file_get_contents($url);
$x=(array)simplexml_load_string($xml,null, LIBXML_NOCDATA);
if(!isset($x['steamID']) || $x['steamID']==""){
  exit;
}

$str = preg_replace_callback('/\\\\u([0-9a-f]{4})/i', 'replace_unicode_escape_sequence', $x['steamID']);
$dat['steamname'] = $str;
$dat['s32'] = $steamID;
$dat['s64'] = $s64;
$dat['vacBanned'] = $x['vacBanned'];
$dat['_cx'] = $cx;
header("Content-type: application/json; charset=UTF-8");
$x=json_encode($dat);
$x = jsonRemoveUnicodeSequences($dat);
echo $x;
