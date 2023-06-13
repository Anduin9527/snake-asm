# snake-asm

## 参考资料
[Searchable Linux Syscall Table for x86 and x86_64 | PyTux](https://filippo.io/linux-syscall-table/)

[Linux System Call Table for x86 64](https://blog.rchapman.org/posts/Linux_System_Call_Table_for_x86_64/)

## 运行
背景音乐的播放依赖于`sox`及其解码器，所以在运行游戏前需要先安装`sox`及其解码器：
```bash
sudo apt install sox libsox-fmt-all
```

## 总体描述
### 程序流程
以下是游戏逻辑的大致流程：

1. 初始化：
   1. 设置游戏界面的大小和初始状态。
   2. 创建贪吃蛇的初始位置和长度
   3. 放置初始数量的苹果。
   4. 创建子进程，用于播放背景音乐。
2. 游戏循环：
   1. 不断监听玩家输入，根据输入来改变贪吃蛇的移动方向。
   2. 每隔一定时间间隔，更新游戏状态。
   3. 判断贪吃蛇是否与边界、自身或苹果发生碰撞，根据情况更新游戏状态。
   4. 如果贪吃蛇吃到了苹果，增加贪吃蛇的长度并生成新的苹果。
   5. 更新游戏界面并显示当前的得分。
3. 游戏结束：
   1. 当贪吃蛇与边界、自身碰撞，或者玩家选择退出游戏时，游戏结束。
   2. 显示游戏结束信息。
   3. 清理游戏状态和界面。关闭用于播放背景音乐的子进程。
   游戏程序流程图如下：
```mermaid
graph LR
    A[初始化] --> B[游戏循环]
    B --> C{是否有输入}
    C -- 有输入 --> D[改变贪吃蛇移动方向]
    C -- 无输入 --> E[更新游戏状态]
    D -->E
    E --> F{是否碰撞}
    F -- 碰撞 --> G[游戏结束]
    F -- 未碰撞 --> H{是否吃到苹果}
    H -- 吃到苹果 --> I[增加贪吃蛇长度]
    H -- 未吃到苹果 --> B
    I --> J[生成新苹果]
    J --> B
    B --> K[更新游戏界面]
    K --> L[显示得分]
    L --> C
    G --> M[显示游戏结束信息]
    M --> N[清理游戏状态和界面]
```
### 总体架构
本程序采用分模块的方式来实现，主要分为以下几个模块：
1. `snake` 贪吃蛇模块，也是游戏的核心模块，游戏的主循环在这个模块中实现
   + `snake.asm`
2. `syscall` 系统调用模块，封装了若干`Linux`系统调用，用于实现游戏的一些功能
   + `syscall.asm`
   + `syscall.mac`
   + `syscall.inc`
3. `print` 打印模块，完成对`write`系统调用的二次封装，并实现了方便的打印字符串和数字的函数
   + `print.asm`
   + `print.mac`
   + `print.inc`
4. `term` 终端模块，封装了`Linux`的终端相关的系统调用与相关结构体的定义
   + `term.asm`
5. `utils` 工具模块，实现了程序中用到的一些工具函数：随机数生成和内存复制
   + `utils.asm`

除了`snake`模块作为游戏的主体流程外，其他模块都是为`snake`模块服务的，都间接或直接地被`snake`模块调用。
为了降低耦合性和内聚性，两个大的模块`print`和`syscall`都进行了解耦操作：其中`.asm`文件是函数的具体实现，`.mac`文件是该模块函数对外的接口（利用`extern`声明），而`.inc`文件是该模块提供的一些宏定义和结构体的定义。
其依赖图如下：
```mermaid
graph TB
   
    A[snake.asm]
    subgraph print模块
      B[print.asm]
      C[print.mac]
      D[print.inc]
    end 

    subgraph syscall模块
      E[syscall.asm]
      F[syscall.mac]
      G[syscall.inc]
    end

    H[term.asm]
    I[utils.asm]
    A --> C
    A --> E
    B --> D
    B --> F
    C --> D
    E --> C
    E --> G
    F --> G
    H --> F
    A --> I
    A --> H
```

## 核心功能介绍
### 绘制部分
本程序的绘制使用的是Linux终端作为游戏界面，出于美观的考量，使用了ANSI控制码来实现一些特殊的控制效果，比如清屏、光标移动、设置文本颜色等。下面先介绍ANSI控制码的一些基本知识，然后再介绍本程序中使用到的ANSI控制码。
ANSI（American National Standards Institute）控制码是一种用于控制文本终端的特殊字符序列。这些字符序列由转义字符（Escape Character）开头，通常是ASCII码中的转义字符 `\033`，也可以是`ESC`键的键码`0x1B`。ANSI控制码的格式如下：
```
\033[<num1>;<num2>...<numN>m
```
+ \033[ 表示控制码的开始
+ `<num1>;<num2>...<numN>`是控制码的参数，可以有多个参数，每个参数之间用分号`;`隔开
在这个程序中，使用了以下 ANSI 转义序列：

1. `cur_reset_seq`：光标位置重置序列，使用`\033[A`将光标位置重置到当前行的起始位置。
2. `cur_home_seq`：光标回到左上角序列，使用`\033[H`将光标位置移动到屏幕的左上角。
3. `cur_hide_seq`：隐藏光标序列，使用`\033[?25l`将光标隐藏。
4. `cur_show_seq`：显示光标序列，使用`\033[?25h`将光标显示。
5. `clear_seq`：清屏序列，使用`\033[J`清空屏幕。
6. `color_reset_seq`：颜色重置序列，使用`\033[m`重置文本颜色和样式。
7. ANSI 颜色序列，包括：
   - `bright_red`：亮红色序列，使用`\033[91m`设置文本颜色为亮红色。
   - `blue`：蓝色序列，使用`\033[34m`设置文本颜色为蓝色。
   - `yellow`：黄色序列，使用`\033[33m`设置文本颜色为黄色。
   - `bright_yellow`：亮黄色序列，使用`\033[93m`设置文本颜色为亮黄色。
   - `bright_gray`：亮灰色序列，使用`\033[90m`设置文本颜色为亮灰色。
   - `miku`：青色序列，使用`\033[36m`设置文本颜色为青色。

除了ANSI之外，程序主要是通过维护一个打印缓冲区来实现绘制的。在绘制的过程中，所有的绘制操作都是先将绘制的内容写入到缓冲区中，然后再通过封装了`write`系统调用的`print`函数将缓冲区的内容写入到终端中。这样做的好处是可以减少系统调用的次数，提高程序的效率。使用宏定义`DEF_STR_DATA`方便的定义字符串常量，使用宏定义`DEF_STR_LEN`方便的获取字符串的长度。同时为了方便输出数字内容，在`print`函数的基础上封装了`print_int`函数，用于输出整数。
### 蛇逻辑部分
蛇的逻辑部分主要是由`snake`模块实现的，`snake`模块的主要功能是实现游戏的主体流程，包括初始化、游戏运行、游戏结束等。在游戏运行的过程中，主要是通过维护一个地图来实现蛇的移动、吃苹果、死亡等逻辑。地图是一个二维数组，每个单元格都有自己的类型，比如自由、墙壁、头部、身体、苹果等。蛇的移动逻辑和判定逻辑如下所述：
蛇的移动逻辑和判定逻辑如下所述：

1. 蛇的移动逻辑：
   - 当接收到按键事件时，更新蛇的移动方向为下一帧的移动方向。
   - 根据当前的移动方向，更新蛇头的坐标。
   - 根据新的蛇头坐标，更新地图上对应位置的单元格类型为蛇头。
   - 根据蛇的长度，遍历蛇的身体部分，依次更新身体部分的坐标和地图上对应位置的单元格类型为蛇身体。
   - 如果蛇头坐标与苹果的坐标相同，表示蛇吃到了苹果，此时不移除蛇尾，只更新地图上对应位置的单元格类型为蛇头。

2. 蛇的判定逻辑：
   - 每次蛇移动时，检查蛇头的坐标是否越界或与墙重叠，若是，则游戏状态置为游戏结束。
   - 检查蛇头的坐标是否与身体的任何一部分重叠，若是，则游戏状态置为游戏结束。
   - 检查蛇的长度是否等于地图上除墙外的可用空间大小，若是，则游戏状态置为游戏结束。

这些逻辑保证了蛇在地图上能够正确移动，并根据移动结果进行相应的判定，以决定游戏的进行或结束。





## 模块介绍
### snake 

#### 宏介绍
首先是定义了基本参数，比如游戏界面的大小以及贪吃蛇的初始长度，最重要的是定义了帧与帧之间的时间间隔，这个时间间隔决定了游戏的速度。
然后定义了蛇移动方向（上下左右）、地图单元格类型（自由，墙壁、头部、身体、苹果）、游戏状态（运行、退出、死亡、狂欢）、按键宏（WASDQ ESC）、地图单元格样式以及长度。同时定义了关于ANSI控制码的宏`DEF_ESC_SEQ`和`DEF_COLOR_SEQ`，用于实现一些特殊的控制效果，比如清屏、光标移动、颜色设置等等。

#### 变量介绍
首先用宏定义了若干ANSI转义序列和颜色序列，以及定义了若干字符串常量，用于在游戏中显示一些信息。关于蛇的部分定义了长度，分数，蛇头位置XY、当前方向和移动方向。游戏方面定义了输入，当前帧数，游戏状态。音乐方面则定义了音乐播放器play及其相关参数。
在 bss 段则定义了若干缓冲区，用于存储地图空闲单元格，蛇身单元格以及打印缓冲区。



#### 函数介绍




### syscall
#### 宏介绍
首先定义了程序中所有用到的系统调用的宏标号，比如`SYS_WRITE`代表`write`系统调用，`SYS_EXIT`代表`exit`系统调用等等。
然后定义了一个宏`SYS`，封装原本使用的`syscall`指令。
同时在`syscall.inc`中定义了文件描述符的宏标号，比如`STDOUT`代表标准输出，`STDIN`代表标准输入等。
#### 变量介绍

结构体方面：定义了要在 term 模块中使用的终端结构体`termios`以及 sleep 函数中使用的`timespec`结构体。


#### 函数介绍
syscall中的所有函数都是对系统调用的二次封装，用于实现游戏的一些功能。值得注意的是在x64系统中，系统调用的参数传递是通过寄存器来实现的，具体的寄存器和参数的对应关系如下：
| 参数 | 寄存器 |
| ---- | ---- |
| rdi | 第一个参数 |
| rsi | 第二个参数 |
| rdx | 第三个参数 |
| r10 | 第四个参数 |
| r8 | 第五个参数 |
| r9 | 第六个参数 |
##### sleep
该函数用于使程序休眠一定的时间。它接受两个参数，分别是秒数和纳秒数，通过调用系统调用函数nanosleep来实现休眠功能。

##### ioctl

该函数用于获取或设置终端属性。它接受两个参数，第一个参数是termios结构体指针，第二个参数用于判断是获取还是设置终端属性。通过调用系统调用函数ioctl来实现终端属性的获取或设置。

##### exit

该函数用于退出程序并返回退出码。它接受一个参数，即退出码，通过调用系统调用函数exit来实现程序的退出。

##### poll

该函数用于轮询事件。它接受一个参数，即存放轮询结果的缓冲区指针。通过调用系统调用函数poll来进行事件的轮询。

##### write

该函数用于向指定文件描述符写入字符串。它接受三个参数，分别是字符串指针、字符串长度和文件描述符。通过调用系统调用函数write来实现字符串的写入。

##### read

该函数用于从标准输入读取数据。它接受两个参数，分别是缓冲区指针和读取的字节数。通过调用系统调用函数read来实现数据的读取。

##### exec

该函数用于执行命令。它接受两个参数，第一个参数是可执行文件路径字符串指针，第二个参数是以0结尾的指针数组，用于传递命令参数。通过调用系统调用函数execve来实现命令的执行。

##### fork

该函数用于创建子进程。它通过调用系统调用函数fork来创建子进程，并根据fork的返回值判断当前是在父进程还是子进程中。

##### kill

该函数用于终止进程。它接受两个参数，分别是要终止的进程ID和信号值。通过调用系统调用函数kill来实现进程的终止。



### print

#### 宏介绍

这里定义了三个宏用于简化汇编代码的编写。

- `DEF_STR_DATA`: 定义字符串数据并计算字符串长度。
- `PRINT_STR_DATA`: 打印字符串数据。
- `PRINT_NEW_LINE`: 打印换行符。

#### 变量介绍

在 data 段中定义了一个名为 "newline" 的字符串常量，其值为 ASCII 码为 10 的换行符。这里使用了之前定义的 `DEF_STR_DATA` 宏来定义字符串并计算字符串长度。

在 bss 段中定义了一个名为 `print_num_buf` 的 8 字节缓冲区，用于存储打印数字时的结果。

#### 函数介绍

##### `print`

函数 `print` 接受两个参数：`rax` 表示字符串的指针，`rdx` 表示字符串的长度。该函数调用 `write` 系统调用来将字符串打印到标准输出。函数执行完后，使用 `ret` 指令返回。

##### `print_num`

函数 `print_num` 接受一个参数：`rax` 表示要打印的数字。该函数将数字转换为字符串，并调用 `print` 函数将结果打印到标准输出。

函数首先将除数 10 存储在 `rbx` 寄存器中，并将数字位数的计数器 `rcx` 初始化为 0。然后使用 `idiv` 指令将 `rax` 寄存器中的数字除以 10，商存储在 `rax` 中，余数存储在 `rdx` 中。将余数加上字符 `'0'` 的 ASCII 码就得到了对应的数字字符，将其存储到缓冲区中。然后将位数计数器 `rcx` 加 1，检查商是否为 0，如果不为 0 则继续循环，直到商为 0。

最后，使用 `print` 函数打印数字的字符串表示。函数执行完后，使用 `ret` 指令返回。



### term

#### 宏介绍

定义了两个常量 `ICANON` 和 `ECHO`，分别表示规范模式和回显模式的标志位。

#### 变量介绍

在 bss 段中定义了两个 `termios` 结构体变量 `stty` 和 `tty`，用于存储旧的和新的终端属性。

#### 函数介绍

定义了两个全局函数 `set_noncanon` 和 `set_canon`，分别用于将终端切换到非规范模式和规范模式。

#####  `set_noncanon`

函数 `set_noncanon` 用于将终端从规范模式切换到非规范模式。该函数通过系统调用 `ioctl` 和参数 `TIOCGETA` 获取当前终端的属性，并将结果存储在 `stty` 中。然后再次调用 `ioctl` 和参数 `TIOCGETA` 获取终端的属性，并将结果存储在 `tty` 中。

接下来，该函数通过逻辑与运算符 `and` 将 `tty` 中的 `ICANON` 和 `ECHO` 标志位清除。最后再次调用 `ioctl` 并使用参数 `TIOCSETA` 将新的终端属性写入内核，从而完成终端从规范模式到非规范模式的切换。

#####  `set_canon`

函数 `set_canon` 用于将终端从非规范模式切换到规范模式。该函数从旧的 `termios` 结构体中恢复终端属性，然后再次调用 `ioctl` 将其写入内核，从而完成终端从非规范模式到规范模式的切换。

### utils

#### 函数介绍

##### memcpy

函数 `memcpy` 使用了 64 位寄存器 `rax`、`rdx` 和 `rcx`，分别表示目标地址、源地址和复制字节数。函数体使用 `mov` 指令将源地址和目标地址存入寄存器 `rsi` 和 `rdi` 中，使用 `cld` 指令清除方向标志位，确保复制操作从低地址向高地址进行，然后使用 `rep movsb` 指令进行内存复制，最后使用 `ret` 指令返回。

##### rand

函数 `rand` 使用了 64 位寄存器 `rax`、`rcx` 和 `rdx`，分别表示最大值、中间变量和余数。函数体使用 `mov` 指令将最大值存入寄存器 `rcx` 中，然后使用 `rdrand` 指令将随机数放入寄存器 `rax` 中。接下来使用 `div` 指令以 `rcx` 作为除数将 `rdx:rax` 除以 `rcx`，商存入 `rax` 中，余数存入 `rdx` 中。最后使用 `ret` 指令返回生成的随机数。

