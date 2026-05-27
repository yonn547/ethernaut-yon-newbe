dalam fallbanck ini aku mencoba membaca alur logika nya dahulu lalu mendapatkan

owner memiliki 100 ether 
lalu ada modifer yang memeriksa apakah kita owner atau bukan 
kemudian ada 3 function 

1.contribute yang bisa kita panggil untuk menjadi kontribusi dalam contract ini yang hanya bisa mengirim kan 0.001 ether 
dan jika kontribusi kita pada contract ini lebih dari owner asli maka kita yang akan "menjadi owner"

2. getContribution yang membuat kita menjadi contribution

3.withdraw yang hanya bisa di gunakan oleh owner untuk menarik uang yang ada di dalam contract  lalu ada receive yang memerlukan nilai ether kita harus lebih dari 0 dan contribution >0 maka kita menjadi owner


maka aku melihat celah di situ bahwa jika dalam fuction withdraw kita dapat menjadi owner dan dapat withdraw jika kita mengirimkan dan memiliki contribution maka bisa kita eksploit dengan 
mengirim dahulu ke contract tersebut agar menjadi contribute dan lalu mengirimkan lagi tanpa memanggil function apapuun agar kita menjadi owner dan meng withdraw ether yang ada di dalam nya
