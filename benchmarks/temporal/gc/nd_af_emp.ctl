fields: next;
precondition:x!=nil * ls(x,nil);
property: AF(emp);
while x=x do
    if * then
        while x!=nil do
            temp:=x.next;
            free(x);
            x:=temp
        od
    else
        while * do
	    y:=new();
	    y.next:=x;
	    x:=y
	od
    fi
od