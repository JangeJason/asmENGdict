# asmENGdict

汇编语言程序设计大作业  
<br />
简易英英词典
<br />
参考https://github.com/Ken-Chy129/emu8086-dictionary
<br />
原代码中有一处小错误，导致从外部导入字典后模糊查找单词会陷入死循环，已改正。

### 实验内容

1. **单词及其英文解释的录入、修改和删除**
   - 录入新单词，把它插入到相应的位置(按词典顺序)，其后跟英文解释、同义词、反义词；（*此功能要求在文件中完成，其它功能可以将单词放在数据段中*）
   -  可修改单词英文解释；
   - 删除单词及其英文解释；
2. **查找**
   - 输入不完整的字符串，会依顺序列出单词前缀和字符串相匹配的单词；
     - 如输入：en则列出：enable, enabled, enact等
   - 查询某个单词英文解释(如enable: to provide with the means or opportunity; to make possible, practical, or easy)，词库中不存在此单词，则提示找不到；
   - 查询某个单词的同义词(如accept: approve)；
   - 查询某个单词的反义词(如win: lose)；
3. **以上结果均需显示**
