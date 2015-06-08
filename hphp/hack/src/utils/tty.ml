(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

open Core

type raw_color =
  | Default
  | Black
  | Red
  | Green
  | Yellow
  | Blue
  | Magenta
  | Cyan
  | White

type style =
  | Normal of raw_color
  | Bold of raw_color

let color_num = function
  | Default -> "0"
  | Black   -> "30"
  | Red     -> "31"
  | Green   -> "32"
  | Yellow  -> "33"
  | Blue    -> "34"
  | Magenta -> "35"
  | Cyan    -> "36"
  | White   -> "37"

let style_num = function
  | Normal c -> color_num c
  | Bold c   -> color_num c ^ ";1"

let print_one (c,s) =
  Printf.printf "\x1b[%sm%s\x1b[0m" (style_num c) (s)

let print strs = List.iter strs print_one

let (spinner, spinner_used) =
  let state = ref 0 in
  (fun () ->
    begin
      let str = List.nth_exn ["-"; "\\"; "|"; "/"] (!state mod 4) in
      state := !state + 1;
      str
    end),
  (fun () -> !state <> 0)

(* ANSI escape sequence to clear whole line *)
let clear_line_seq = "\r\x1b[0K"

let print_clear_line chan =
  if Unix.isatty (Unix.descr_of_out_channel chan)
  then Printf.fprintf chan "%s%!" clear_line_seq
  else Printf.fprintf chan "\n%!"

(* Read a single char and return immediately, without waiting for a newline.
 * `man termios` to see how termio works. *)
let read_char () =
  let tty = Unix.(openfile "/dev/tty" [O_RDWR] 0o777) in
  let termio = Unix.tcgetattr tty in
  let new_termio = {termio with Unix.
    c_icanon = false;
    c_vmin = 1;
    c_vtime = 0;
  } in
  Unix.tcsetattr tty Unix.TCSANOW new_termio;
  let buf = String.create 1 in
  let bytes_read = UnixLabels.read tty ~buf ~pos:0 ~len:1 in
  Unix.tcsetattr tty Unix.TCSANOW termio;
  assert (bytes_read = 1);
  buf.[0]

(* Prompt the user to pick one character out of a given list. If other
 * characters are entered, the prompt repeats indefinitely. *)
let read_choice message choices =
  let char_to_string = String.make 1 in
  let rec loop () =
    Printf.printf "%s (%s)%!" message
      (String.concat "|" (List.map choices char_to_string));
    let choice = read_char () in
    print_newline ();
    if List.mem choices choice then choice else loop ()
  in loop ()
