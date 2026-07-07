:- module(apt_maintainer, [
    actually_remove_apt_packages/4
]).

:- use_module(ssh_bridge).

% We're using a list here because the setup time for SSH connections is significant, 
% and we want to avoid repeated connections for each file.
actually_remove_apt_packages(Host, Port, User, Packages) :-
    py_remote_executor(Host, Port, User, "remove_packages", 
        _{packages: Packages}, Response),
    ( Response.status = "success" ->
        format("[INFO] Successfully removed apt packages.~n")
    ; format("[ERR] Failed to remove apt packages: ~w~n", [Response.message]),
      fail
    ).
