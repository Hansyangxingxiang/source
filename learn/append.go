package main  
import "fmt"


func main() {
   teststr := make([]string, 0 ,10)
   teststr = append(teststr,"aa")
   teststr = append(teststr,"bb")
   teststr = append(teststr,"cc")
   teststr1 := make([]string, 0 ,3)
   teststr1 = append(teststr1,"dd")
   teststr1 = append(teststr1,"ee")
   teststr = append(teststr,teststr1...)
   fmt.Printf("len:%d cap:%d",len(teststr), cap(teststr))
}
