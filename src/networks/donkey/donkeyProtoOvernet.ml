(* Copyright 2001, 2002 b8_bavard, b8_fee_carabine, INRIA *)
(*
    This file is part of mldonkey.

    mldonkey is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    mldonkey is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with mldonkey; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

open Printf2
open Md4

  open AnyEndian

open CommonOptions
open Options
open DonkeyOptions
open CommonTypes
open LittleEndian
open CommonGlobals
open DonkeyMftp

type peer = 
  { 
    peer_md4 : Md4.t;
    mutable peer_ip : Ip.t;
    peer_port : int;
    peer_kind : int;
    mutable peer_last_msg : int;
  }
  
let buf_peer buf p =
  buf_md4 buf p.peer_md4;
  buf_ip buf p.peer_ip;
  buf_int16 buf p.peer_port;
  buf_int8 buf p.peer_kind
  
let get_peer s pos = 
  let md4 = get_md4 s pos in
  let ip = get_ip s (pos+16) in
  let port = get_int16 s (pos+20) in
  let kind = get_int8 s (pos+22) in
  {
    peer_md4 = md4;
    peer_ip = ip;
    peer_port = port;
    peer_kind = kind;
    peer_last_msg = BasicSocket.last_time ();
  }, pos + 23
  
type t =
| OvernetConnect of 
(* client md4 *) Md4.t *
(* IP address *) Ip.t *
(* port *)       int *
(* kind *)       int

| OvernetConnectReply of 
(* The last peer of this list is the sender *)
  peer list

| OvernetSearch of 
(* 2 is OK for most searches, number of replies? *) int * 
(* searched file or keyword *) Md4.t

| OvernetPublicize of
(* client md4 *) Md4.t *
(* IP address *) Ip.t *
(* port *)       int *
(* kind *)       int

| OvernetPublicized

| OvernetSearchReply of 
  Md4.t *
  peer list (* the two closest peers in the binary tree of md4s *)

(*

RCVD: SEARCH REPLY
17:54:05.411029 217.231.48.129.5509 > 192.168.0.2.5682:  udp 65
MESSAGE SIZE: 65
dec: [
(227)
(15)
(11)(198)(22)(129)(235)(182)(173)(78)(160)(117)(29)(147)(133)(82)(9)(66)
(2) npeers on which we can iter the request

(11)(199)(46)(146)(72)(115)(64)(95)(26)(146)(99)(178)(47)(103)(227)(118)
(217)(88)(209)(92)
(172)(46)
(2)
  
(11)(196)(75)(211)(89)(29)(190)(67)(234)(253)(153)(118)(62)(126)(231)(98)
(217)(231)(48)(129)
(133)(21)
(0)

  ]
*)

| OvernetGetSearchResults of 
  Md4.t * int * int * int

(*
RCVD: SEARCH GET REPLIES
17:54:15.309167 192.168.0.2.5682 > 217.231.48.129.5509:  udp 23 (DF)
MESSAGE SIZE: 23
dec: [
(227)
(16)
(11)(198)(22)(129)(235)(182)(173)(78)(160)(117)(29)(147)(133)(82)(9)(66)
(0)(0)(0)(100)(0)]
*)


| OvernetSearchResult of
(* query *)  Md4.t *
(* md4 result *) Md4.t *
(* tags *) tag list

(*
RCVD: ONE REPLY
17:54:15.862868 217.231.48.129.5509 > 192.168.0.2.5682:  udp 71
MESSAGE SIZE: 71
dec: [
(227)
(17)
(11)(198)(22)(129)(235)(182)(173)(78)(160)(117)(29)(147)(133)(82)(9)(66)
(25)(119)(145)(24)(179)(65)(171)(160)(216)(218)(6)(95)(109)(228)(202)(169)
(1)(0)(0)(0)
(2)
(3)(0)  loc
(25)(0) bcp://80.131.174.215:4662
]
*)
(*
RCVD: ONE REPLY
17:54:15.936396 217.231.48.129.5509 > 192.168.0.2.5682:  udp 70
dec: [
(227)
(17)
(11)(198)(22)(129)(235)(182)(173)(78)(160)(117)(29)(147)(133)(82)(9)(66)
(53)(213)(239)(225)(189)(192)(230)(24)(6)(92)(231)(203)(2)(102)(21)(168)
(1)(0)(0)(0)
(2)
(3)(0) l o c
(24)(0) b c p : / / 2 4 . 1 7 0 . 8 1 . 2 2 7 : 4 6 6 2]
  
RCVD: ONE REPLY
17:54:15.945381 217.231.48.129.5509 > 192.168.0.2.5682:  udp 103
MESSAGE SIZE: 103
dec: [
(227)
(17)
(11)(198)(22)(129)(235)(182)(173)(78)(160)(117)(29)(147)(133)(82)(9)(66)
(189)(53)(62)(130)(142)(23)(226)(254)(35)(118)(167)(74)(171)(219)(193)(93)
(1)(0)(0)(0)
(2)
(3)(0) l o c
(57)(0) b c p : / / b d 3 5 3 e 8 2 8 e 1 7 e 2 f e 2 3 7 6 a 7 4 a a b d b c 1 5 d : 8 0 . 3 4 . 1 2 7 . 2 1 5 : 6 3 2 4
  ]
*)

(*
  UNKNOWN: opcode 18
ascii: [ x(128) F(249) `(246) L(157)(217)(146)(143)(127)(244)(190) g(233)(0)(0)(0)(0)]
dec: [
(227)
(18)
(120)(128)(70)(249)(96)(246)(76)(157)(217)(146)(143)(127)(244)(190)(103)(233)
(0)(0)(0)(0)
]
*)

| OvernetNoResult of Md4.t
  
(*
UNKNOWN: opcode 19
22:40:26.123479 192.168.0.3.8368 > 62.255.150.48.6411:  udp 66 (DF)
MESSAGE SIZE: 66
ascii: [(227)(19)(248)(237) * J A(180) A ] 7 O(137)(138)(151) > I(18)(29) @(212)(166)(227)(0) [(140)(236)(220) V(2) $(10)(130) y(2)(0)(0)(0)(2)(1)(0)(1)(14)(0) i n d e x . h t m l . o l d(3)(1)(0)(2)(191)(0)(0)(0)]
dec: [
(227)
(19)
(248)(237)(42)(74)(65)(180)(65)(93)(55)(79)(137)(138)(151)(62)(73)(18)  "html"
(29)(64)(212)(166)(227)(0)(91)(140)(236)(220)(86)(2)(36)(10)(130)(121)   MD4
(2)(0)(0)(0)
(2)(1)(0)(1)
(14)(0) index.html.old
(3)(1)(0)(2)
(191)(0)(0)(0)]


  
UNKNOWN: opcode 19
22:41:36.040963 192.168.0.3.8368 > 128.8.51.16.9683:  udp 102 (DF)
MESSAGE SIZE: 102
ascii: [(227)(19)(29) @(212)(166)(227)(0) [(140)(236)(220) V(2) $(10)(130) y g(198) i s Q(255) J(236) )(205)(186)(171)(242)(251)(227) F(1)(0)(0)(0)(2)(3)(0) l o c 8(0) 
dec: [
(227)
(19)
(29)(64)(212)(166)(227)(0)(91)(140)(236)(220)(86)(2)(36)(10)(130)(121)
(103)(198)(105)(115)(81)(255)(74)(236)(41)(205)(186)(171)(242)(251)(227)(70)
(1)(0)(0)(0)
(2)
(3)(0) "loc"
(56)(0) "bcp://67c6697351ff4aec29cdbaabf2fbe346:62.243.53.52:4665"

*)
  
| OvernetPublish of 
(* keyword or file md4 *) Md4.t *
(* md4 of file or client md4 *) Md4.t *
  tag list

(* Published or not Published ??? *)
| OvernetPublished of Md4.t

| OvernetUnknown of int * string

| OvernetGetMyIP of int

| OvernetGetMyIPResult of Ip.t

| OvernetGetMyIPDone

| OvernetFirewallConnection of Md4.t*int

| OvernetFirewallConnectionACK of Md4.t

| OvernetFirewallConnectionNACK of Md4.t

| OvernetPeerNotFound of peer

| OvernetUnknown21 of peer



let names_of_tag =
  [
    "\001", "filename";
    "\002", "size";
    "\003", "type";
    "\004", "format";
  ]
  


let write buf t =
  match t with
  | OvernetConnect (md4, ip, port, kind) ->
      buf_int8 buf 10;
      buf_md4 buf md4;
      buf_ip buf ip;
      buf_int16 buf port;
      buf_int8 buf kind
  
  | OvernetConnectReply peers ->
      buf_int8 buf 11;
      buf_list16 buf_peer buf peers      
  
  | OvernetPublicize (md4, ip, port, kind) ->
      buf_int8 buf 12;
      buf_md4 buf md4;
      buf_ip buf ip;
      buf_int16 buf port;
      buf_int8 buf kind

  | OvernetPublicized ->
      buf_int8 buf 13

  | OvernetSearch (kind, md4) ->
      buf_int8 buf 14;
      buf_int8 buf kind;
      buf_md4 buf md4
        
  | OvernetSearchReply (md4, peers) ->
      buf_int8 buf 15;
      buf_md4 buf md4;
      buf_list8 buf_peer buf peers
  
  | OvernetGetSearchResults (md4, kind, min, max) ->
      buf_int8 buf 16;
      buf_md4 buf md4;
      buf_int8 buf kind;
      buf_int16 buf min;
      buf_int16 buf max
      
  | OvernetSearchResult (md4, r_md4, r_tags) ->
      buf_int8 buf 17;
      buf_md4 buf md4;
      buf_md4 buf r_md4;
      buf_tags buf r_tags names_of_tag

  | OvernetNoResult md4 ->
      buf_int8 buf 18;
      buf_md4 buf md4

  | OvernetPublish (md4, r_md4, r_tags) ->
      buf_int8 buf 19;
      buf_md4 buf md4;
      buf_md4 buf r_md4;
      buf_tags buf r_tags names_of_tag
      
  | OvernetPublished md4 ->
      buf_int8 buf 20;
      buf_md4 buf md4

  | OvernetGetMyIP port ->
      buf_int8 buf 27;
      buf_int16 buf port

  | OvernetGetMyIPResult (ip) ->
      buf_int8 buf 28;
      buf_ip buf ip

  | OvernetGetMyIPDone ->
      buf_int8 buf 29
      
  | OvernetFirewallConnection(md4,port) ->
      buf_int8 buf 24;
      buf_md4 buf md4;
      buf_int16 buf port

  | OvernetFirewallConnectionACK(md4) ->
      buf_int8 buf 25;
      buf_md4 buf md4

  | OvernetFirewallConnectionNACK(md4) ->
      buf_int8 buf 26;
      buf_md4 buf md4

  | OvernetPeerNotFound peer ->
      buf_int8 buf 33;
      buf_peer buf peer

  | OvernetUnknown21 peer ->
      buf_int8 buf 21;
      buf_peer buf peer
      
  | OvernetUnknown (opcode, s) ->
      buf_int8 buf opcode;
      Buffer.add_string buf s

    
let parse opcode s =  
  try
    match opcode with  
    | 10 -> 
        if !verbose_overnet then
            lprintf "RCVD: CONNECT MESSAGE (10)\n";
        let md4 = get_md4 s 0 in
        let ip = get_ip s 16 in
        let port = get_int16 s 20 in
        let kind = get_int8 s 22 in
        OvernetConnect (md4, ip, port, kind)
    | 11 -> 
        if !verbose_overnet then
            lprintf "RCVD: CONNECT REPLY (11)\n";
        let peers, pos = get_list16 get_peer s 0 in
        OvernetConnectReply peers
    | 12 -> 
        if !verbose_overnet then
            lprintf "RCVD: PUBLICIZE (12)\n";
        let md4 = get_md4 s 0 in
        let ip = get_ip s 16 in
        let port = get_int16 s 20 in
        let kind = get_int8 s 22 in
        OvernetPublicize (md4,ip,port,kind)
    | 13 ->
        if !verbose_overnet then
            lprintf "RCVD: PUBLICIZED (13)\n";
	OvernetPublicized
    | 14 -> 
        if !verbose_overnet then
          lprintf "RCVD: SEARCH MESSAGE (14)\n";
        let kind = get_int8 s 0 in
        let md4 = get_md4 s 1 in
        OvernetSearch (kind, md4)
    
    | 15 -> 
        if !verbose_overnet then
            lprintf "RCVD: SEARCH REPLY (15)\n";
        let md4 = get_md4 s 0 in
        let peers, pos = get_list8 get_peer s 16 in
        OvernetSearchReply (md4, peers)
    
    | 16 ->
        if !verbose_overnet then
            lprintf "RCVD: SEARCH GET REPLIES (16): ";
        let md4 = get_md4 s 0 in
        let kind = get_int8 s 16 in
        let min = get_int16 s 17 in
        let max = get_int16 s 19 in
        if !verbose_overnet then
            lprintf "MD4[%s] KIND[%d] MIN[%d] MAX[%d]\n" (Md4.to_string md4) kind min max;
        OvernetGetSearchResults (md4, kind, min, max)  
    
    | 17 ->
        if !verbose_overnet then
            lprintf "RCVD: ONE REPLY (17)\n";
        let md4 = get_md4 s 0 in
        let r_md4 = get_md4 s 16 in
        let r_tags, pos = get_tags s 32 names_of_tag in
        OvernetSearchResult (md4, r_md4, r_tags)
    
    | 18 ->
        if !verbose_overnet then
            lprintf "RCVD: ONE REPLY (18)\n";
        let md4 = get_md4 s 0 in
        OvernetNoResult md4
        
    | 19 ->
        if !verbose_overnet then
            lprintf "RCVD: PUBLISH (19)\n";
        let md4 = get_md4 s 0 in
        let r_md4 = get_md4 s 16 in
        let r_tags, pos = get_tags s 32 names_of_tag in
        OvernetPublish (md4, r_md4, r_tags)
        
    | 20 ->
        if !verbose_overnet then
            lprintf "RCVD: PUBLISHED (20)\n";
        let md4 = get_md4 s 0 in
        OvernetPublished md4

    | 21 ->
        (* idem as 33, but IP seem to be a low ID *)
(*        if !verbose_overnet then begin
*)
            lprintf "Received code %d message.\nDump: " opcode; dump s; lprint_newline ();
(*          end;
*)
        let peer, _ = get_peer s 0 in
        OvernetUnknown21 peer

    | 24 ->
        if !verbose_overnet then
            lprintf "RCVD: OVERNET FIREWALL CONNECTION (24)\n";
        let md4 = get_md4 s 0 in
        let port = get_int16 s 16 in
        OvernetFirewallConnection(md4,port)

    | 25 ->
        if !verbose_overnet then
            lprintf "RCVD: OVERNET FIREWALL CONNECTION ACK (25)\n";
        let md4 = get_md4 s 0 in
        OvernetFirewallConnectionACK(md4)

    | 26 ->
        if !verbose_overnet then
            lprintf "RCVD: OVERNET FIREWALL CONNECTION NACK (26)\n";
        let md4 = get_md4 s 0 in
        OvernetFirewallConnectionNACK(md4)

    | 27 ->
	if !verbose_overnet then
            lprintf "RCVD: GETMYIP MESSAGE (27)\n";
        OvernetGetMyIP (get_int16 s 0)
    | 28 -> 
	if !verbose_overnet then
            lprintf "RCVD: GETMYIPRESULT MESSAGE (28)\n";
        let ip = get_ip s 0 in
        OvernetGetMyIPResult (ip)
    | 29 -> 
	if !verbose_overnet then
            lprintf "RCVD: GETMYIPDONE MESSAGE (29)\n";
        OvernetGetMyIPDone
        
    | 33 ->
      if !verbose_overnet then
            lprintf "RCVD: PEER NOT FOUND (33)\n";
        let peer, _ = get_peer s 0 in
        OvernetPeerNotFound peer
        
    | _ ->
        lprintf "UNKNOWN: opcode %d\n" opcode;
        dump s;
        lprint_newline ();
        OvernetUnknown (opcode, s)
  with e ->
      lprintf "Error %s while parsing opcode %d\n" (Printexc2.to_string e) opcode;
      dump s;
      lprint_newline ();
      OvernetUnknown (opcode, s)
      
let udp_handler f sock event =
  match event with
    UdpSocket.READ_DONE ->
      UdpSocket.read_packets sock (fun p -> 
          try
            let pbuf = p.UdpSocket.content in
            let len = String.length pbuf in
            if len < 2 || 
              int_of_char pbuf.[0] <> 227 then 
              begin
                if !CommonOptions.verbose_unknown_messages then begin
                    lprintf "Received unknown UDP packet\n";
                    dump pbuf;
                  end
              end 
            else 
              begin
                let t = parse (int_of_char pbuf.[1]) (String.sub pbuf 2 (len-2)) in
                f t p
              end
          with e ->
              lprintf "Error %s in udp_handler, dump of packet:\n"
                (Printexc2.to_string e); 
              dump p.UdpSocket.content;
              lprint_newline ()	    
      );
  | _ -> ()
      