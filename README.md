# snake-asm

## 参考资料
[Searchable Linux Syscall Table for x86 and x86_64 | PyTux](https://filippo.io/linux-syscall-table/)

[Linux System Call Table for x86 64](https://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/)
### 系统调用
### 播放音乐
为了能够播放音乐，安装了`sox`及其解码器，然后使用exec系统调用，使用play命令播放音乐
```bash
sudo apt install sox libsox-fmt-all
```