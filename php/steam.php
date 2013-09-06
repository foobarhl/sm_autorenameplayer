<?php

function steam32to64($steamid)
{

  $split = explode(":", $steamid); // STEAM_?:?:??????? format

  $x = substr($split[0], 6, 1);
  $y = $split[1];
  $z = $split[2];

  $w = ($z * 2) + 0x0110000100000000 + $y;
  return($w);

}


if(!isset($_REQUEST['s'])){
  exit;
}
$s=$_REQUEST['s'];

$s64 = steam32to64($s);

$url="http://steamcommunity.com/profiles/".$s64."/?xml=1";
$xml=file_get_contents($url);
$x=(array)simplexml_load_string($xml,null, LIBXML_NOCDATA);
$dat['steamname'] = $x['steamID'];
$dat['s32'] = $s;
$dat['s64'] = $s64;
$dat['_cx'] = (integer)$_REQUEST['cx'];

//$array = json_decode(json_encode((array)simplexml_load_string($xml)),1);
header("Content-type: application/json");
$x=json_encode($dat);
echo $x;
