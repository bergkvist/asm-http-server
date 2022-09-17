server: server.o
	ld $^ -o $@

server.o: server.nasm
	nasm -felf64 $^