package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path"
	"strconv"
	"strings"

	"image"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"

	"gocv.io/x/gocv"
)

const (
	imageDir = "/data/images/"
	mlURL    = ""
)

// Item type
type Item struct {
	gorm.Model
	ImageFileName string
	User          int
	Label         string
}

type itemPostRequest struct {
	imageFileName string
	user          int
	label         string
}

type itemGetResponse struct {
	imageFileName string
	user          int
	label         string
}

func init() {
	// create /data/images and /data/tmp

	_ = os.Mkdir("/data/images", os.ModeDir)
	_ = os.Mkdir("/data/tmp", os.ModeDir)
}

func registerHandlers(db *gorm.DB) error {

	http.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "api available")

		fmt.Fprint(os.Stdout, r.Header)
	})

	http.HandleFunc("/label", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			fmt.Fprint(w, "Method not implemented")
			return
		}

		r.ParseMultipartForm(10 << 21)

		file, handler, err := r.FormFile("image")
		if err != nil {
			fmt.Println("Error Retrieving the File")
			fmt.Println(err)
			return
		}
		defer file.Close()
		fmt.Printf("Uploaded File: %+v\n", handler.Filename)
		fmt.Printf("File Size: %+v\n", handler.Size)
		fmt.Printf("MIME Header: %+v\n", handler.Header)

		tempFile, err := ioutil.TempFile("/data/tmp", "upload-*.png")
		if err != nil {
			fmt.Println(err)
		}
		defer tempFile.Close()
		defer os.Remove(tempFile.Name())

		fileBytes, err := ioutil.ReadAll(file)
		if err != nil {
			fmt.Println(err)
			os.Remove(tempFile.Name())
		}

		_, err = tempFile.Write(fileBytes)
		if err != nil {
			fmt.Println(err)
			os.Remove(tempFile.Name())
		}

		fmt.Println(tempFile.Name())

		mat := gocv.IMRead(tempFile.Name(), gocv.IMReadColor)

		gocv.Resize(mat, &mat, image.Point{X: 256, Y: 256}, 1, 1, gocv.InterpolationDefault)

		// fmt.Fprint(w, mat.Channels(), "\n")
		// fmt.Fprint(w, mat.Rows(), "\n")
		// fmt.Fprint(w, mat.Cols(), "\n")
		// fmt.Fprint(w, mat.Size(), "\n")
		// fmt.Fprint(w, mat.ToBytes(), "\n")
		matbytes := mat.ToBytes()
		var out [256][256][3]byte

		for i := 0; i < 256; i++ {
			for j := 0; j < 256; j++ {
				for k := 0; k < 3; k++ {
					out[i][j][2-k] = matbytes[k+j*3+i*256*3]
				}
			}
		}

		encodedMat, err := json.Marshal(out)
		if err != nil {
			fmt.Println(err)
			return
		}

		// New Buffer.
		var b bytes.Buffer

		// Write strings to the Buffer.
		b.WriteString("{ \"data\": ")
		b.WriteString(string(encodedMat))
		b.WriteString("}")

		// Convert to a string and print it.
		// fmt.Println(b.String())

		resp, err := http.Post(mlURL, "application/json", &b)
		if err != nil {
			fmt.Println(err)
		}

		// var respstr []byte
		respstr := make([]byte, 32)

		n, err := resp.Body.Read(respstr)
		if err != nil {
			fmt.Println(err)
		}

		fmt.Fprint(w, string(respstr), n)
	})

	http.HandleFunc("/item", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost && r.Method != http.MethodGet {
			fmt.Fprint(w, "Method not implemented")
			return
		}
		switch r.Method {
		case http.MethodPost:
			r.ParseMultipartForm(10 << 21)

			var req itemPostRequest

			file, handler, err := r.FormFile("image")
			if err != nil {
				fmt.Println("Error Retrieving the File")
				fmt.Println(err)
				return
			}
			defer file.Close()
			fmt.Printf("Uploaded File: %+v\n", handler.Filename)
			fmt.Printf("File Size: %+v\n", handler.Size)
			fmt.Printf("MIME Header: %+v\n", handler.Header)

			req.user, err = strconv.Atoi(r.Form.Get("user"))
			if err != nil {
				fmt.Print(w, err)
			}
			req.label = r.Form.Get("label")

			if req.label == "" {
				fmt.Fprint(w, "Incorrect request")
				return
			}

			tempFile, err := ioutil.TempFile("/data/images", "upload-*.jpg")
			if err != nil {
				fmt.Println(err)
			}
			defer tempFile.Close()

			fileBytes, err := ioutil.ReadAll(file)
			if err != nil {
				fmt.Println(err)
				os.Remove(tempFile.Name())
			}

			_, err = tempFile.Write(fileBytes)
			if err != nil {
				fmt.Println(err)
				os.Remove(tempFile.Name())
			}

			req.imageFileName = strings.Replace(tempFile.Name(), imageDir, "", 1)

			db.Create(&Item{ImageFileName: req.imageFileName, Label: req.label, User: req.user})

			fmt.Fprintf(w, "Successfully Uploaded File\n")

		case http.MethodGet:
			params := r.URL.Query()

			imgFilename := params.Get("image")

			img, err := os.Open(path.Join(imageDir, imgFilename))
			if err != nil {
				fmt.Println(err)
				fmt.Fprint(w, "failed to retrive image")
			}
			defer img.Close()

			w.Header().Set("Content-Type", "image/jpg")
			io.Copy(w, img)
		}

	})

	http.HandleFunc("/items", func(w http.ResponseWriter, r *http.Request) {
		params := r.URL.Query()

		user, err := strconv.Atoi(params.Get("user"))
		if err != nil {
			fmt.Print(w, err)
		}

		var items []Item
		db.Where("User = ?", user).Find(&items)

		response, err := json.Marshal(items)
		if err != nil {
			fmt.Println(err)
		}

		fmt.Fprint(w, string(response))
	})

	return nil
}

func main() {
	db, err := gorm.Open(sqlite.Open("/data/data.db"), &gorm.Config{})
	if err != nil {
		panic("failed to connect database")
	}

	db.AutoMigrate(&Item{})

	if err := registerHandlers(db); err != nil {
		panic(err)
	}

	if port := os.Getenv("port"); port != "" {
		if err := http.ListenAndServeTLS(port, "./cert.pem", "./key.pem", nil); err != nil {
			panic(err)
		}
	} else {
		if err := http.ListenAndServeTLS(":9000", "./cert.pem", "./key.pem", nil); err != nil {
			panic(err)
		}
	}
}
