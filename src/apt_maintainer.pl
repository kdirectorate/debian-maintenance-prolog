:- module(apt_maintainer, [
    pending_autoremove/2
]).

/* Teaching note:
   The bridge will run "apt-get autoremove --dry-run" (or equivalent)
   and return parsed package lists. This module only contains the
   decision rules: "is it worth running autoremove right now?"
*/
pending_autoremove([], false).
% TODO: real rules that look at the list and decide