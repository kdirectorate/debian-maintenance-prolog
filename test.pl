has_extension(Path) :-
    sub_atom(Path, _, 1, _, '.').

test :-
    writeln('--- Testing has_extension ---'),
    ( has_extension('foo.log') -> writeln('foo.log : has extension') ; writeln('foo.log : no extension') ),
    ( has_extension('foo') -> writeln('foo : has extension') ; writeln('foo : no extension') ),
    ( has_extension('archive.tar.gz') -> writeln('archive.tar.gz : has extension') ; writeln('archive.tar.gz : no extension') ).
