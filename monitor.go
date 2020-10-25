package main  // 代码包声明语句。
import "fmt"
import "errors" //系统包用来输出的
import "strings"
import "os/exec"
import "bytes"
//import "os"

type CasCoreInfo struct {
	CoreId  string
	HDDName string
	DevName string
}

type CasCacheInfo struct {
	CacheId   string
	CacheName string
	Core      []CasCoreInfo
}


func parseStr(CasCacheStr string) ([]CasCacheInfo, error) {
	var cache_list []CasCacheInfo
	var core CasCoreInfo
	cachelist := strings.Split(CasCacheStr, "cache")
	if len(cachelist) < 2 {
		return cache_list, errors.New("cache str is nil")
	}
    fmt.Printf("cachelist:%v", cachelist)
	for i := 1; i < len(cachelist); i++ {
		var cache CasCacheInfo
		cacheStr := strings.Fields(cachelist[i])
		if len(cacheStr) < 2 {
			return cache_list, errors.New("cache info is nil")
		}
		cache.CacheId = cacheStr[0]
		cache.CacheName = cacheStr[1]
		corelist := strings.Split(cachelist[i], "core")
        fmt.Printf("corelist:%v", corelist)
		if len(corelist) < 2 {
			return cache_list, errors.New("core str is nil")
		}
		for j := 1; j < len(corelist); j++ {
			coreStr := strings.Fields(corelist[j])
			if len(coreStr) < 5 {
				return cache_list, errors.New("core id is nil")
			}
			core.CoreId = coreStr[0]
			core.HDDName = coreStr[1]
			core.DevName = coreStr[4]
            fmt.Printf("core.DevName:%s", core.DevName)
			cache.Core = append(cache.Core, core)
		}
		cache_list = append(cache_list, cache)
	}
	return cache_list, nil
}

func getStoreCasCache() ([]CasCacheInfo, error) {
	var cas []CasCacheInfo
	var out bytes.Buffer
    
    /*
	cmd := exec.Command("source", "/etc/profile")
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
        fmt.Printf("failed error：%s\n", err.Error())
		return cas, err
	}
    */

    //os.Setenv("PS1", "\u@\[\e[1;93m\]\h\[\e[m\]:\w\$\[\e[m\]")
	c := "casadm -L -o csv |tr ',' ' '"
	cmd := exec.Command("sh", "-c", c)
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
        fmt.Printf("cmd：%s failed error：%s\n", c, err.Error())
		return cas, err
	}
    fmt.Printf("out:%s", out.String())
	cas, err = parseStr(out.String())
	if err != nil {
		return cas, err
	}
	return cas, nil
}


func main() {
    /*
    env := os.Environ()
    for k, v := range env {
        fmt.Println(k, v)
    }
    */
    getStoreCasCache()
    fmt.Printf("hello\n")
}
