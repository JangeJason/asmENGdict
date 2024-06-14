; multi-segment executable file template.

data segment
    file db "d:\words.txt", 0    ;词典在电脑中的路径实际路径为\emu8086\vdrive\D\words.txt
    file_code dw ?
              
    words_number dw 0       ;词典缓冲区中的单词数量
    buf db 128 dup(" ")     ;字符串缓冲区，用于输出字符串到屏幕，也可用于存入字符至words
    
    words db 6400 dup(" ")  ;词典缓冲区，可从外部导入词典至此处，后续可添加，最后可将此处保存至外部词典
    ;每个单词占100个字节单元，每100字节单元的：1-20单元存单词，21-60单元存解释，61-80存近义词，81-100存反义词
                            
    insert_place dw 0       ;在模糊查找时用于记录模糊查找成功的单词数量，便于调用循环进行输出
    likely dw 0
    likely_pos dw -1
    exist dw 0              ;插入单词时若已存在，则置为一
    find1_or_delete0 dw 1
     
    str0 db "Dictionary$"
    str1n0 db "Exit   : 1$"
    str1n1 db "Search: 2$"
    str1n2 db "input  : 3$"
    str1n3 db "Edit   : 4$"
    str1n4 db "Delete: 5$"
    str1n5 db "Choose : $"
    str2 db "Explain:$"
    str3 db "Synonym:$"
    str4 db "Antonym:$"
    str5 db "Thanks for your using!$"
    
    fun1 db "Search:$"
    fun2 db "Input:$"
    fun3 db "Edit$"
    fun4 db "Delete:$"
        
    choose_error db "Please choose 1 to 5!$"                    ;这些都是提示语，便于使用词典
    press_return db "Press any key to return!$"
    waiting_msg db "Enter the infomations!$"
    find_msg db "Deleting the word...$"
    searching_msg db "Searching! Please wait!$"
    word_exist db "Word already exists!$"
    nofound_msg db "Can not find the word!  Press any to continue...$"
    success_msg db "Success!  Press any key to return!$"
    search_like_msg db "Not Found! But the related words are below:$"
ends

stack segment
    dw   128  dup(0)
ends

code segment
start:
; set segment registers:
    mov ax, data
    mov ds, ax
    mov es, ax

    ; add your code here
            
scroll macro n, ulr, ulc, lrr, lrc, att           ;清屏或上卷宏定义
    mov ah, 6                                     ;清屏或上卷
    mov al, n                                     ;N=上卷行数，N=0清屏
    mov ch, ulr                                   ;左上角行号
    mov cl, ulc                                   ;左上角列号
    mov dh, lrr                                   ;右下角行号
    mov dl, lrc                                   ;右下角列号
    mov bh, att                                   ;卷入行属性
    int 10h
endm
   
curse macro cury, curx
    mov ah, 2                                     ;置光标位置
    mov dh, cury                                  ;行号
    mov dl, curx                                  ;列号
    mov bh, 0                                     ;当前页
    int 10h
endm
    
input_word macro begin, len       ;向词典缓冲区中读入单词、解释、同反义词均用此宏定义。begin为开始地址，len为长度
local next, now_place, compare, move_loop, insert_loop, other, move, insert, result, additional, exist, exit
    mov ah, 0ah                                   ;输入
    lea dx, buf
    int 21h
    mov ax, begin
    cmp ax, 0
    jnz next
    call waiting
next:
    mov bl, begin                                 ;当begin为0时，代表插入的是单词
    sub bl, 0                                     
    jnz insert                                   
    cld                                           ;是单词则需要找到在哪插入（按字母顺序），并把原本单词向后移动留出位置
    mov cx, words_number                          ;已存储的单词数量                            
now_place:                                      
    cmp cx, 0
    jz additional                                 
    push cx                                   ;存储已经访问到第几个单词            
    mov ax, cx                            
    dec ax
    xor bx, bx
    mov bl, 100                             
    mul bl                                    ;记录第cx-1(因为下标从0开始)个单词的首地址 
    mov di, ax                            
    lea si, buf[2]                           ;单词的第一个字母地址
    mov cl, [si-1]                           ;新增单词的长度          
compare:
    lodsb
    cmp al, words[di]                       ;从第一个字母开始一次比较
    jb result                               ;因为是从后往前比较，所以如果新加入的词小则结束内层循环
    cmp al, words[di]
    ja move                                 ;大于当前词则结束循环进行插入（因为上一次判断已经确定小于后一个词）,插在第cx+1即words[cx]
    inc di
    loop compare                            ;相等则继续内层循环
    cmp words[di], ' '                      ;buf部分完全相同，则判断words是否结束
    jz exist                                ;如果words也结束了，代表这两个个单词一样，即已存在
result:
    pop cx
    loop now_place
    push cx                                 ;找到位置后记录这个位置
    jmp move
additional:
    push 0
    jmp insert
exist:
    scroll 23, 5, 40, 9, 78, 0B0h        ;输入层清空               
    curse 6, 56
    mov ah, 09h
    lea dx, word_exist                   ;单词存在提示语
    int 21h
    curse 8, 56
    mov ah, 09h
    lea dx, press_return                 ;按键返回提示语
    int 21h
    mov ah, 0                            ;等待输入后返回
    int 16h       
    scroll 23, 5, 40, 9, 78, 0B0h
    scroll 23, 5, 1, 9, 38, 0B0h            
    call choose_bar
    mov word_exist, 1                    ;将存在标志置1，以便后续跳出
    jmp exit
move:
    std                                       ;si和di递减
    mov ax, words_number                      ;取出总共几个单词
    xor bx, bx
    mov bl, 100
    mul bl                                      ;算出总共几个字节
    lea bx, words                               ;取出words基址
    add ax, bx                                ;加上变址得到最后一个单词的后一个单词的地址
    dec ax                                    ;减一得到最后一个单词的最后一个字母
    mov si, ax
    add ax, 100                               ;每个都要移动100位
    mov di, ax
    mov ax, words_number                      ;取出总共几个单词
    pop cx                                    ;当前要插在第几个单词后面
    sub ax, cx                                ;计算应该移动几个单词
    mov insert_place, cx                      ;将这一次要插在哪记录起来，以便后面insert
    xor bx, bx
    mov bl, 100 
    mul bl
    mov cx, ax                                  ;作为循环次数
    cmp cx, 0
    jz insert
move_loop:
    lodsb                                       ;将si（即每一位先保存到al）
    stosb                                       ;再把al移动到di所指
    loop move_loop                              
insert:
    cld
    mov ax, insert_place                  ;要插入单词的位置传给ax
    xor bx, bx
    mov bl, 100                            
    mul bl                                ;计算出变址，即应该在哪开始存储
    lea bx, words
    add ax, bx
    mov bx, begin
    add ax, bx                            ;加上偏移量
    mov di, ax
    lea si, buf[2]
    xor cx, cx
    mov cl, [si-1]                        ;字符串长度
    mov ax, len
    sub ax, cx
    push ax 
insert_loop:
    lodsb                                 ;插入单词
    stosb
    loop insert_loop
    pop cx
other:                                    ;剩下的位置都插入空格
    mov al, ' '
    stosb
    loop other
exit:      
endm

edit_word macro begin, len          ;在词典缓冲区中修改单词、解释、同反义词均用此宏定义。begin为开始地址，len为长度
    local loop1, loop2              ;与插入单词的宏类似
    mov ah, 0ah                                   ;输入
    lea dx, buf
    int 21h
    cld 
    mov cx, insert_place 
    mov ax, cx
    dec ax
    xor bx, bx
    mov bl, 100                            
    mul bl                                        ;计算出变址，即应该在哪开始修改
    lea bx, words
    add ax, bx
    mov bx, begin
    add ax, bx                                    ;加上偏移量
    mov di, ax
    lea si, buf[2]
    xor cx, cx
    mov cl, [si-1]
    mov ax, len                                   ;计算剩下多少字符需要置为空
    sub ax, cx
    push ax 
loop1:
    lodsb
    stosb
    loop loop1
    pop cx
loop2:
    mov al, ' '
    stosb
    loop loop2
endm 

delete_word macro                                 ;根据likely_pos的位置删除单词
    local loop1
    mov ax, likely_pos                            ;删除哪个位置的单词
    cld                                               
    dec ax
    xor bx, bx
    mov bl, 100                                   ;likely_pos的序号是单词序号，要乘以100达到在缓冲区中的位置
    mul bl                                        ;算出总共几个字节
    lea bx, words                                 ;取出words基址                       
    
    add ax, bx                                    ;加上变址得到要删除的单词的地址
    mov di, ax
    add ax, 100                                   ;每个都要移动100位
    mov si, ax
    mov ax, words_number                          ;取出总共几个单词
    mov cx, likely_pos                                
    sub ax, cx                                    ;计算相差几个单词
    inc ax                                        ;计算实际要移动的单词数量
    xor bx, bx
    mov bl, 100 
    mul bl
    mov cx, ax                                    ;作为循环次数
loop1:
    lodsb                                     ;将si（即每一位先保存到al）
    stosb                                     ;再把al移动到di所指
    loop loop1   
endm



;------------主函数由此开始--------------------------------------------------------------


import:                                           ;从文件导入字典数据

    mov ah, 3ch                                  ;没有导入的字典文件，于是新建字典文件
    mov cx, 0
    lea dx, file                         
    int 21h                                      

    mov al, 0                                     ;打开方式为写
    mov ah, 3DH                                   ;打开文件
    lea dx, file
    int 21h
    mov file_code, ax                             ;保存文件码
    mov ah, 3FH                                   ;读取文件
    mov bx, file_code                             ;将文件代号传送至bx
    mov cx, 6400
    lea dx, words                                 ;数据缓冲区地址 
    int 21h
    mov bl, 100 
    div bl
    mov ah, 0                                     ;计算出读取了多少单词，ah要赋为0，单词数仅在al中
    mov words_number, ax      
    mov bx, file_code                             ;将文件代号传送至bx
    mov ah, 3EH                                   ;关闭文件
    int 21h
        
ui:                                                 ;定义ui界面
    scroll 0, 0, 0, 24, 79, 02                      ;清屏
    scroll 25, 0, 0, 24, 79, 0F0h                   ;开外窗口
    scroll 23, 1, 1, 3, 78, 0B0h                    ;最顶层框
    scroll 23, 5, 1, 9, 38, 0B0h                    ;功能选择层
    scroll 23, 5, 40, 9, 78, 0B0h                   ;单词层
    scroll 23, 11, 1, 15，78, 0B0h                  ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                  ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                 ;反义词层  
    
    call init_str    

choose:
    mov ah, 0                                     ;读入选择
    int 16h                                           
    mov ah, 0eh                                   ;显示输入的字符
    int 10h                                              
    cmp al, 49                                    ;选择1,表示退出
    jz export                               
    cmp al, 50                                    ;选择2,表示查找
    jz search
    cmp al, 51                                    ;选择3,表示插入
    jz input
    cmp al, 52                                    ;选择4,表示修改
    jz edit                                    
    cmp al, 53                                    ;选择5,表示删除
    jz delete
     
    scroll 23, 5, 1, 9, 38, 0B0h                  ;没有选择正确的功能，输入层清空
    curse 6, 4                                    
    mov ah, 09h
    lea dx, choose_error                          ;显示报错
    int 21h
    curse 8, 4  
    mov ah, 09h
    lea dx, press_return                          ;按键返回
    int 21h                            
    mov ah, 0
    int 16h
    scroll 23, 5, 1, 9, 38, 0B0h                  ;重新加载功能选择层
    call choose_bar
    jmp choose
search:
    lea dx, fun1                                 
    call init_function                            ;在功能选择层显示当前执行的操作为查找
    curse 7, 56                                  
    call searching                                ;键入指针指到单词层，进入searching子程序
    search_exit:
    jmp choose
input:
    mov exist, 0
    lea dx, fun2                          
    call init_function                            ;在功能选择层显示当前执行的操作为增加
    curse 7, 56                                    
    input_word 0, 20                              ;插入单词
    mov ax, exist
    cmp ax, 1
    jz input_exit                                 
    inc words_number                              ;单词数量+1
    curse 13, 12
    input_word 20, 40                             ;插入注释
    curse 20, 12                                
    input_word 60, 20                             ;插入同义词
    curse 20, 51
    input_word 80, 20                             ;插入反义词
    call input_done                               ;完成后，清空界面，进入input_done子程序
    
    lea dx, file                                  ;根据题目要求，插入功能在文件中完成，所以立马保存至字典文件，如此直接关闭程序也可防止字典未保存
    mov al, 1                                     ;打开方式为写
    mov ah, 3DH                                   ;打开文件
    int 21h
    mov file_code, ax                             ;保存文件码
    mov ax, words_number                          ;写入的字节数
    mov bl, 100
    mul bl
    mov cx, ax
    mov ah, 40H                                   ;写入文件
    mov bx, file_code                             ;将文件代号传送至bx
    lea dx, words                                 ;数据缓冲区地址 
    int 21h       
    mov bx, file_code                             ;将文件代号传送至bx
    mov ah, 3EH                                   ;关闭文件
    int 21h
    input_exit:
    jmp choose
    
edit:
    lea dx, fun3                                  ;在功能选择层显示当前执行的操作为修改 
    call init_function                                   
    curse 7, 56
    call find                                     ;调用查找函数，返回单词位置到likely_pos，查找不到则输出提示信息，并置likely_pos为-1
    mov cx, likely_pos                                 
    cmp cx, -1                                    ;-1则代表查询不到，退出
    jz edit_exit                        
    mov insert_place, cx
    curse 13, 12
    edit_word 20, 40                            ;修改解释，起始地址为20，长度40
    curse 20, 12
    edit_word 60, 20                            ;修改同义词，起始地址为60，长度20
    curse 20, 51
    edit_word 80, 20                            ;修改反义词，起始地址为80，长度20
    call input_done
    edit_exit:
    jmp choose
    
delete:
    lea dx, fun4                                 
    call init_function                            ;在功能选择层显示当前执行的操作为删除
    curse 7, 56
    mov find1_or_delete0, 0                                  
    call find                                     ;调用查找函数，返回单词位置到likely_pos，查找不到则输出提示信息，并置likely_pos为-1
    mov cx, likely_pos
    cmp cx, -1                                    ;-1则代表查询不到，退出
    jz delete_exit
    delete_word                                   ;根据pos位置删除单词
    dec words_number                              ;单词数量-1
    call input_done                                  
    delete_exit:
    jmp choose
    
export:                      ;功能号1，保存并退出，若在，因为本代码的删除操作不是在文件中完成的，
                             ;所以如果存在删除操作，并不会直接更改字典文件，只会在字典缓冲区中更改，所以退出的时候要保存最新版本的字典
                             
    lea dx, file                 
    mov al, 1                       ;打开方式为写
    mov ah, 3DH                     ;打开文件
    int 21h
    mov file_code, ax               ;保存文件码
    mov ax, 64            ;写入的字节数
    mov bl, 100
    mul bl
    mov cx, ax
    mov ah, 40H                     ;写入文件
    mov bx, file_code               ;将文件代号传送至bx
    lea dx, words                   ;数据缓冲区地址 
    int 21h       
    mov bx, file_code               ;将文件代号传送至bx
    mov ah, 3EH                     ;关闭文件
    int 21h
           
    call exit_str                   ;退出消息
    mov ax, 4c00h                   ;结束程序
    int 21h
                
init_str proc                                     ;显示字典界面字符串子程序
    push ax
    push dx
    curse 2, 35
    mov ah, 09h                                   ;显示字典
    lea dx, str0                                
    int 21h
    curse 12, 4
    mov ah, 09h                                   ;显示注释
    lea dx, str2
    int 21h
    curse 18, 4
    mov ah, 09h                                   ;显示同义词
    lea dx, str3
    int 21h
    curse 18, 43
    mov ah, 09h                                   ;显示反义词
    lea dx, str4
    int 21h
    call choose_bar                               ;显示功能选择区
    pop dx
    pop ax
    ret
init_str endp

exit_str proc                                     ;程序结束页面子程序
    push dx
    push ax
    scroll 0, 1, 1, 23, 78, 0B0h                  ;清屏
    curse 11, 28
    mov ah, 09h
    lea dx, str5                                  ;显示结束提示语
    int 21h
    mov ah, 0                                     ;等待键入后程序结束
    int 16h       
    pop ax
    pop dx
    ret       
exit_str endp

choose_bar proc                                   ;显示功能选择区的提示语
    curse 5, 4     
    mov ah, 09h                                   ;退出功能
    lea dx, str1n0
    int 21h
    curse 6, 4     
    mov ah, 09h                                   ;查找功能
    lea dx, str1n1
    int 21h
    curse 7, 4     
    mov ah, 09h                                   ;插入功能
    lea dx, str1n2
    int 21h
    curse 8, 4     
    mov ah, 09h                                   ;修改功能
    lea dx, str1n3
    int 21h
    curse 9, 4     
    mov ah, 09h                                   ;删除功能
    lea dx, str1n4
    int 21h
    curse 7, 20     
    mov ah, 09h                                   ;显示选择消息
    lea dx, str1n5
    int 21h
    ret
choose_bar endp

searching proc                                    ;查找功能子程序
    push ax
    push bx
    push cx
    push dx
    mov likely, 0                                   ;模糊查询结果数likely先置为0
    mov ah, 0ah                                     ;输入
    lea dx, buf                                  
    int 21h
    call search_msg                                  ;调用提示消息
    cld                                       
    mov cx, words_number                             ;已存储的单词数量
    cmp cx, 0
    jz notequal_search                          ;cx为0则肯定找不到单词
loop1_search:                                 
    push cx                                     ;存储已经访问到第几个单词
    mov ax, cx                            
    dec ax
    xor bx, bx
    mov bl, 100
    mul bl                                    ;记录第cx-1个单词的首地址 
    mov di, ax
    dec di                                    ;后面统一加1,所以这里提前减1
    xor cx, cx                                       
    lea si, buf[2]                           ;单词的第一个字母地址
    mov cl, [si-1]                            ;新增单词的长度          
loop2_search:
    inc di
    lodsb
    cmp al, words[di]
    jne next_search                         ;当前单词出现字母不相等,判断下一个单词
    loop loop2_search                       ;字母相等继续往后判断
    inc di                                  ;buf部分判断完，全部相同则运行到此处
    cmp words[di], ' '                      ;判断words部分是否结束
    jz search_exact                         ;若都结束则表明查找到一样的单词，则精确输出结果
    pop cx
    push cx
    mov likely_pos, cx
    inc likely                              ;增加模糊查询的结果数量后继续下一个单词的查询   
    next_search:                            ;出现不相等则到外循环判断下一个单词
    pop cx                            
    loop loop1_search
    cmp likely, 0
    jnz search_like                         ;likely不为0则输出模糊查询结果，否则输出查找不到单词
    
notequal_search:                                    ;运行到此处说明匹配不到单词
    scroll 23, 5, 1, 9, 38, 0B0h                   ;功能选择层
    scroll 23, 5, 40, 9, 78, 0B0h                  ;单词层
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                 ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                ;反义词层               
    curse 13, 18
    mov ah, 09h                                     ;解释层显示没有找到的消息
    lea dx, nofound_msg
    int 21h
    mov ah, 0                                       ;等待输入
    int 16h       
    scroll 23, 11, 1, 15，78, 0B0h                  ;解释层
    call init_str
    jmp search_exit
    
search_exact:                             ;精确查找
    cld
    pop ax
    dec ax
    xor bx, bx
    mov bl, 100                            
    mul bl                                ;计算出变址，即应该在哪开始输出
    lea bx, words
    add ax, bx                            ;单词所在位置
    add ax, 20                            ;从words[20]开始,为解释
    mov si, ax                                               
    lea di, buf
    mov cx, 40
loop_explain:                          ;输出解释
    lodsb
    stosb
    loop loop_explain
    curse 13, 12                       ;最后一位传入$，方便输出
    mov buf[39], '$'
    mov ah, 09h
    lea dx, buf
    int 21h
    lea di, buf
    mov cx, 20
loop_synonym:                          ;输出同义词
    lodsb                           
    stosb
    loop loop_synonym 
    curse 20, 12
    mov buf[19], '$'
    mov ah, 09h
    lea dx, buf
    int 21h
    lea di, buf 
    mov cx, 20
loop_antonym:                          ;输出反义词
    lodsb
    stosb
    loop loop_antonym
    curse 20, 51  
    mov buf[19], '$'
    mov ah, 09h
    lea dx, buf
    int 21h
    mov ah, 0                             ;全部完成后，等待输入任意键结束
    int 16h                             
    scroll 23, 5, 1, 9, 38, 0B0h                   ;功能选择层
    scroll 23, 5, 40, 9, 78, 0B0h                  ;单词层
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                 ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                ;反义词层
    call init_str
    jmp searching_exit
    
search_like:                                       ;模糊查找
    scroll 23, 11, 1, 23，78, 0B0h                 ;前缀单词层
    curse 13, 8
    mov ah, 09h
    lea dx, search_like_msg
    int 21h
    mov cx, likely
search_like_loop1:
    push cx
    mov ax, likely_pos
    inc likely_pos                           ;每运行一次pos跳到下一个单词
    dec ax
    xor bx, bx
    mov bl, 100                            
    mul bl                                  ;计算出变址，即应该在哪开始输出
    lea bx, words
    add ax, bx                              ;单词所在位置
    mov si, ax                                   
    lea di, buf
    mov cx, 20
    search_like_loop2:                      ;输出模糊查找的单词在屏幕
        lodsb
        stosb
        loop search_like_loop2
    curse 20, 14
    mov buf[19], '$'
    mov ah, 09h
    lea dx, buf                                                                        
    int 21h
    scroll 1, 15, 1, 21，78, 0B0h          ;上卷一行，再输出下一个
    pop cx
    dec cx
    cmp cx, 0
    jnz search_like_loop1
    mov ah, 0                               ;完成后等待输入任意键结束
    int 16h
    scroll 23, 11, 1, 23，78, 0FFh                 ;前缀单词层                     
    scroll 23, 5, 1, 9, 38, 0B0h                   ;功能选择层
    scroll 23, 5, 40, 9, 78, 0B0h                  ;单词层
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                 ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                ;反义词层
    call init_str                                  ;初始化界面
searching_exit:    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
searching endp

find proc                                         ;精确寻找单词子程序 ，因为要修改，所以需要精确查找
    push dx                                       ;方法与上面search功能的精确查找类似
    push cx
    push bx                                      
    push ax
    mov ah, 0ah                                   ;输入
    lea dx, buf
    int 21h
    mov cx, find1_or_delete0
    cmp cx, 0 
    jz deleting                                   ;这里有两个功能，当find1_or_delete0
    jmp waiting_find                              
deleting:
    call delete_find                              ;为0时是显示正在删除的提示语
    jmp find_ok
waiting_find:
    call waiting                                  ;为1时是修改功能下的提示语
    jmp find_ok    
find_ok:
    cld                                       
    mov cx, words_number                           ;已存储的单词数量
    cmp cx, 0
    jz notequal_find                            ;cx为0则肯定找不到单词
loop1_find:                                 
    push cx                                   ;存储已经访问到第几个单词
    mov ax, cx                            
    dec ax
    xor bx, bx
    mov bl, 100
    mul bl                                    ;记录第cx-1个单词的首地址 
    mov di, ax
    dec di                                    ;后面统一加1,所以这里提前减1
    xor cx, cx                                       
    lea si, buf[2]                           ;单词的第一个字母地址
    mov cl, [si-1]                            ;新增单词的长度          
loop2_find:
    inc di
    lodsb
    cmp al, words[di]
    jne out_find                            ;当前单词出现字母不相等
    loop loop2_find                         ;字母相等继续往后判断
    inc di                                  ;buf部分判断完，全部相同则运行到此处
    cmp words[di], ' '                      ;判断words部分是否结束
    jnz out_find                            ;没有结束则继续判断
    pop cx                                  ;结束则说明找到匹配单词
    mov likely_pos, cx
    jmp find_exit                         
out_find:                                   ;出现不相等则到外循环判断下一个单词
    pop cx                            
    loop loop1_find
notequal_find:                              ;运行到此处说明匹配不到单词
    mov likely_pos, -1
    scroll 23, 5, 1, 9, 38, 0B0h                   ;功能选择层
    scroll 23, 5, 40, 9, 78, 0B0h                  ;单词层
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                 ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                ;反义词层               
    curse 13, 18
    mov ah, 09h                                    ;解释层显示没有找到的消息
    lea dx, nofound_msg
    int 21h
    mov ah, 0                                       ;等待输入任意键后退出
    int 16h       
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    call init_str
find_exit:                               
    pop ax
    pop bx
    pop cx
    pop dx
    ret
find endp

    
init_function proc                                  ;用于在功能选择层中输出当前功能提示字符
    push ax
    push bx
    push cx
    push dx
    scroll 23, 5, 1, 9, 38, 0B0h
    scroll 23, 5, 40, 9, 78, 0B0h                   ;功能选择层
    curse 7, 15                                 
    mov ah, 09h
    pop dx        
    int 21h
    pop cx
    pop bx
    pop ax
    ret
init_function endp

input_done proc                                    ;插入功能结束后刷新页面，并给出提示完成
    push ax
    push bx
    push cx
    push dx
    scroll 23, 5, 1, 9, 38, 0B0h                   ;输入层
    scroll 23, 5, 40, 9, 78, 0B0h                  ;单词层
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                 ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                ;反义词层  
    curse 13, 20
    mov ah, 09h                                   ;输入层显示成功消息
    lea dx, success_msg
    int 21h
    mov ah, 0                                     ;等待输入
    int 16h                                      
    scroll 23, 13, 1, 15，78, 0B0h                 ;解释层
    call init_str
    pop dx
    pop cx
    pop bx
    pop ax
    ret
input_done endp

waiting proc                                      ;等待提示
    push dx
    push cx
    push bx
    push ax
    curse 7, 9                                 
    mov ah, 09h                                  ;在功能选择层显示提示信息
    lea dx, waiting_msg        
    int 21h
    pop ax
    pop bx
    pop cx
    pop dx
    ret
waiting endp

delete_find proc                                      ;正在删除的提示
    push dx
    push cx
    push bx
    push ax
    mov find1_or_delete0, 1
    curse 7, 9                                 
    mov ah, 09h
    lea dx, find_msg        
    int 21h
    scroll 23, 11, 1, 15，78, 0B0h                 ;解释层
    scroll 23, 17, 1, 23，38, 0B0h                 ;同义词层
    scroll 23, 17, 40, 23, 78, 0B0h                ;反义词层
    pop ax
    pop bx
    pop cx
    pop dx
    ret
delete_find endp

search_msg proc                                      ;正在查找提示
    push dx
    push cx
    push bx
    push ax
    curse 7, 8                                 
    mov ah, 09h
    lea dx, searching_msg        
    int 21h
    pop ax
    pop bx
    pop cx
    pop dx
    ret
search_msg endp

ends   
end start ; set entry point and stop the assembler.
