(* Non recursive directory comparision *)

open Forest
open Filename

module CostMon = CostNameMon
let exName = "dircomp"

let dir1 = "dir1"
let dir2 = "dir2"

[%%forest {|
  universal = directory { asc is [ f :: file | f <- matches RE ".*", $get_kind f_att = AsciiK$];
                          bin is [ b :: file | b <- matches RE ".*", $get_kind b_att = BinaryK$];
                          sym is [ l :: link | l <- matches RE ".*", $get_kind l_att = SymK$];
                          dir is [ d :: universal | d <- matches RE ".*", $get_kind d_att = DirectoryK$]
                        }
|}]


let get_dir1 () = (Printf.sprintf "%s/%s/%s" (Sys.getcwd ()) exName dir1)
let get_dir2 () = (Printf.sprintf "%s/%s/%s" (Sys.getcwd ()) exName dir2)

let name_exists e1_md md2 f =
	match e1_md.info with
	| Some e1_info ->
		List.fold_left (fun prev e2_md -> (match e2_md.info with
											| Some e2_info -> ((f e2_info.full_path) = (f e1_info.full_path)) || prev
											| None -> failwith "A md (e2_md) is empty")) false md2
	| None -> failwith "No info in e1_md"

let file_exists f1_md md2 = name_exists f1_md md2 (fun full_path -> basename full_path)

let dir_exists = file_exists

let compare_mds md1 md2 name_f field_f =
	let result1 = List.fold_left (fun prev md -> prev && (name_f md (field_f md2) )) true (field_f md1) in
	let result2 = List.fold_left (fun prev md -> prev && (name_f md (field_f md1) )) true (field_f md2) in
	result1 && result2

let compare_files md1 md2 =
	let asc_f = (fun md -> md.data.asc_md.data) in
	let bin_f = (fun md -> md.data.bin_md.data) in
	(compare_mds md1 md2 file_exists asc_f) && (compare_mds md1 md2 file_exists bin_f)

let compare_dirs md1 md2 =
	let dir_f = (fun md -> md.data.dir_md.data) in
	compare_mds md1 md2 dir_exists dir_f

let get_path md = match md.info with 
					| Some info -> info.full_path
					| None -> ""

let rec find_dir md dirpath = match md with
| h::t -> if (basename (get_path h)) = (basename dirpath)
		  then h
		  else find_dir t dirpath
| [] -> failwith "Directory not found"

let rec recurse_dirs md1 md2 =
	let result = (compare_files md1 md2) && (compare_dirs md1 md2) in
	if result then
		if (md1.data.dir_md.data <> [] && md2.data.dir_md.data <> []) then
		List.fold_left (fun prev md ->
						prev && (recurse_dirs md (find_dir md2.data.dir_md.data (get_path md) ))
					) true md1.data.dir_md.data
		else if (md1.data.dir_md.data = [] && md2.data.dir_md.data = []) then true else false
	else false

let _ =
	run (
	(*universal_new is generated by Forest to allow us to create a cursor that will allow us to load the file*)
	universal_new (get_dir1 ()) >>= fun d1cur -> (* Cursor for d1 *)
	universal_new (get_dir2 ()) >>= fun d2cur -> (* Cursor for d2 *)
	load d1cur >>= fun (rep1,md1) -> (* Loading the cursor to get the representation and metadata *)
	load d2cur >>= fun (rep2,md2) -> (* Similarly, loading the cursor for directory2*)
	let result = (compare_files md1 md2) && (recurse_dirs md1 md2) in
	print_string (if result then "The directory and file structure (names and paths) are equivalent.\n" 
							else "The directory and file structure (names and paths) are not equivalent.\n");
	return ();
	)