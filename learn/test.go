
package main  // 代码包声明语句。
import "fmt" //系统包用来输出的
import "strings"

func main() {
    // 打印函数调用语句。用于打印输出信息。
   var n1 int64
   var n2 int64
   n1 = -20000000
   n2 = -1000
   fmt.Printf("n1:%d n2:%d\n",n1,n2)
   fmt.Println((n1 ^ n2) >> 63)
   teststr := make([]string, 0 ,16)
   teststr = append(teststr,"aa")
   //teststr = append(teststr,"bb")
   catsstr :=  strings.Join(teststr, " or ")
   fmt.Printf("%s",catsstr)

}
