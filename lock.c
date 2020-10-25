#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>

int main(int argc, char *argv[]) {
    int fd = open(argv[1], O_RDONLY);
    struct flock lock;
    if(fd == -1) {
        perror("open");
        return -1;
    }
    //对锁变量设置初值
    lock.l_type = F_RDLCK;
    lock.l_whence = SEEK_SET;
    lock.l_start = 0;
    lock.l_len = 0;
    lock.l_pid = 0;
    //对文件描述符加锁
    int f = fcntl(fd, F_SETLK, &lock);
    if(f == -1) {
        perror("fcntl");
        return -1;
    }
    getchar();
    //close 将关闭掉文件描述符上的所有记录锁
    close(fd);
    return 0;
}
