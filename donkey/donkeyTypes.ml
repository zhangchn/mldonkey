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

open Md4
open CommonTypes

type server (*[]*) = {
    mutable server_server : server CommonServer.server_impl;
    mutable server_ip : Ip.t;
    mutable server_cid : Ip.t;
    mutable server_port : int (*[16]*);
    mutable server_sock : TcpBufferedSocket.t option;
    mutable server_nqueries : int;
    mutable server_search_queries : CommonTypes.search Fifo.t;
    mutable server_users_queries : bool Fifo.t;
    mutable server_connection_control : connection_control;
    mutable server_score : int (*[16]*);
    mutable server_tags : CommonTypes.tag list;
    mutable server_nusers : int (*[16]*);
    mutable server_nfiles : int (*[24]*);
    mutable server_name : string;
    mutable server_description : string;
    mutable server_users: user list;
    mutable server_next_udp : float;
    mutable server_master : bool;
    mutable server_mldonkey : bool;
    mutable server_last_message : float; (* used only by mldonkey server *)
    
    mutable server_queries_credit : int;
    mutable server_waiting_queries : file list;
  } 


and user = {
    user_user : user CommonUser.user_impl;
    user_md4 : Md4.t;
    mutable user_name : string;
    user_ip : Ip.t;
    user_port : int;
    user_tags : CommonTypes.tag list;
    user_server : server;
  }

(*
and server_search = {
    search_search : CommonTypes.search;
    mutable nhits : int;
  }
*)

(*
and local_search = {
    search_search : CommonTypes.search;
    mutable search_handler : (search_event -> unit);
    mutable search_xs_servers : server list;
    mutable search_overnet : bool;
  }
*)

and result = {
    result_result : result CommonResult.result_impl;
    mutable result_index : Store.index;
  }

and search_event =
(*  Result of result *)
| Waiting of int

and file_change_kind = 
  NoFileChange
| FileAvailabilityChange
| FileInfoChange

and client_change_kind = 
  NoClientChange
| ClientStateChange
| ClientFriendChange
| ClientInfoChange
| ClientFilesChange

and server_change_kind = 
  NoServerChange
| ServerStateChange
| ServerUsersChange
| ServerInfoChange
| ServerBusyChange

and availability = bool array

(*
    mutable client_is_friend : friend_kind;
*)

and brand = 
  Brand_unknown
| Brand_edonkey
| Brand_mldonkey1
| Brand_mldonkey2
| Brand_overnet
| Brand_oldemule
| Brand_newemule
| Brand_server
  
and client (*[]*) = {
    client_client : client CommonClient.client_impl;
    mutable client_kind : location_kind;
    mutable client_source : source option;
    mutable client_md4 : Md4.t;
    mutable client_chunks : availability;
    mutable client_sock : TcpBufferedSocket.t option;
    mutable client_power : int (*[4]*);
    mutable client_block : block option;
    mutable client_zones : zone list;
    mutable client_connection_control : connection_control;
    mutable client_file_queue : (file * availability) list;
    mutable client_source_for : file list;
    mutable client_next_view_files :  float;
    mutable client_all_files : result list option;
    mutable client_tags: CommonTypes.tag list;
    mutable client_name : string;
    mutable client_all_chunks : string;
    mutable client_rating : int (*[16]*);
    mutable client_upload : upload_info option;
    mutable client_checked : bool;
    mutable client_chat_port : int (*[2]*);
    mutable client_connected : bool;
    mutable client_on_list : bool;
(* statistics *)
    mutable client_already_counted : bool;
    mutable client_last_filereqs : float;    
    mutable client_downloaded : Int64.t;
    mutable client_uploaded : Int64.t;
    mutable client_brand : brand;
    mutable client_banned : bool;
  }
  
and upload_info = {
    mutable up_file : file;
    mutable up_pos : int32;
    mutable up_end_chunk : int32;
    mutable up_chunks : (int32 * int32) list;
    mutable up_waiting : bool;
  }
  
and chunk = 
  PresentTemp
| AbsentTemp
| PartialTemp of block
| PresentVerified
| AbsentVerified
| PartialVerified of block
  
and block = {
    mutable block_present: bool;
    block_begin : int32;
    block_end : int32;
    mutable block_zones : zone list;
    mutable block_nclients : int;
    mutable block_pos : int;
    block_file : file;
  }
  
and zone = {
    mutable zone_begin : int32;
    mutable zone_end : int32;
    mutable zone_nclients : int;
    mutable zone_present : bool;
    zone_file : file;
  }
  
and source = {
    source_addr : Ip.t * int;
    mutable source_client: client_kind; 
  }

and client_kind = 
  SourceClient of client
| SourceRecord of float (* last connection attempt *)
  
and file = {
    file_file : file CommonFile.file_impl;
    file_md4 : Md4.t;
    file_exists : bool;
(*    mutable file_size : int32; *)
    mutable file_nchunks : int;
    mutable file_chunks : chunk array;
    mutable file_chunks_order : int array;
(*    mutable file_age : float; *)
    mutable file_chunks_age : float array;
(*    mutable file_fd : Unix32.t; *)
    mutable file_all_chunks : string;
    mutable file_absent_chunks : (int32 * int32) list;
    mutable file_filenames : string list;
    mutable file_nlocations : int;
    mutable file_md4s : Md4.t list;
    mutable file_format : format;
    mutable file_available_chunks : int array;
    mutable file_enough_sources : bool;

(* These are the good sources: they have a chunk we want, or we are trying 
to connect them. *)
    mutable file_sources : client Intmap.t; 
    
    mutable file_emerging_sources : source list;
    mutable file_concurrent_sources : source Fifo.t;
    mutable file_old_sources : source Fifo.t;
    mutable file_all_sources : ((Ip.t * int), source) Hashtbl.t;
(*
    mutable file_last_downloaded : (int32 * float) list;
    mutable file_last_time : float;
    mutable file_last_rate : float;
*)
    
(* the time the file state was last computed and sent to guis *)
    mutable file_shared : file CommonShared.shared_impl option;
  }

and file_to_share = {
    shared_name : string;
    shared_size : int32;
    mutable shared_list : Md4.t list;
    mutable shared_pos : int32;
    mutable shared_fd : Unix32.t;
    shared_shared : file_to_share CommonShared.shared_impl;
  }
  
module UdpClientMap = Map.Make(struct
      type t = location_kind
      let compare = compare
    end)

  
type udp_client = {
    udp_client_ip : Ip.t;
    udp_client_port : int;
    udp_client_can_receive : bool;
    mutable udp_client_last_conn : float;
  }
  
and file_group = {
    mutable group : udp_client UdpClientMap.t;
  }


type old_result = result
    
exception NoSpecifiedFile
exception Already_done

type shared_file_info = {
    sh_name : string;
    sh_md4s : Md4.t list;
    sh_mtime : float;
    sh_size : int32;
  }
  
