CC=gcc

# No -Werror per your requirement
CFLAGS=-Wall -Wextra -O0 -g --coverage -DRUNTESTS=1
LDFLAGS=--coverage -lm

TARGET=pex3
SRCS=pex3.c listAsLinkedList.c unitTest.c rpnUtils.c
OBJS=$(SRCS:.c=.o)

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $<

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET) *.o
	rm -f *.gcda *.gcno *.gcov
