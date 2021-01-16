package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"

	"image"

	"gocv.io/x/gocv"
)

type mlRequest struct {
	data string
}

func registerHandlers() error {

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
					out[i][j][2-k] = matbytes[k+j*3+i*256]
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

		resp, err := http.Post("http://localhost:9001/", "application/json", &b)
		if err != nil {
			fmt.Println(err)
		}

		// var respstr []byte
		respstr := make([]byte, 10<<21)

		n, err := resp.Body.Read(respstr)
		if err != nil {
			fmt.Println(err)
		}

		fmt.Fprint(w, string(respstr), n)
	})

	http.HandleFunc("/item", func(w http.ResponseWriter, r *http.Request) {
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

		tempFile, err := ioutil.TempFile("/data/images", "upload-*.png")
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

		fmt.Fprintf(w, "Successfully Uploaded File\n")
	})

	return nil
}

func main() {

	if err := registerHandlers(); err != nil {
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
