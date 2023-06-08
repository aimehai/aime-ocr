myObject = new Vue({
  el: '#file_list',
  data: {
    data: [],
    listFilter: [],
    selectedList: [],
    name_delete: '',
    formats: [],
    allSelected: false,
    pageNo: 1,
    pageSize: 10,
    listIdCheck: [],
    size: 10,
    pageCount: 0,
    socket: null,
    category: [],
    listCategories: [],
    brand_filter: [],
    listBrands: [],
    listSelectBrand: [],
    status_filter: [],
    listStatus: [],
    cate_name: null,
    dateFrom: null,
    dateTo: null,
    showPage: [],
    packId: null,
    tmp_key_delete : null,
    typedelete:null,
    files: null,
    listFile: [],
    packageName:null,
    name_upload:null,
    isForCar: false,
  },
  beforeMount: function () {
    this.data = localData.data.reverse();
    this.packId = localData.pack_id
    this.formats = localData.format;
    this.packageName = decodeURI(window.location.pathname.split("/").pop())

    if(this.data[0] && this.data[0]['type'] == "車検証認識"){
        this.data.map((item,ind) =>{ 
          if(!item['result']){
            item['result'] = {"brand": (langChoose =='ja' ? '未知の' :"Unknown")}
            return;
          }
          if(!item['result']['brand'] ||item['result']['brand'] ==null ){
            item['result']['brand'] = (langChoose =='ja' ? '未知の' :"Unknown")
          } 
        })
        this.data.sort((a, b) => a['result']['brand'].localeCompare(b['result']['brand']))
        this.isForCar = true;
    }

    this.listBrands = [...new Set(this.data.map(item => item['result']? item['result']['brand'] : (langChoose =='ja' ? '未知の' :"Unknown")))].filter(a => a != null);
    this.listCategories = [...new Set(this.data.map(item => item['type']))].filter(a => a != null);
    this.listStatus = langChoose =='ja' ? ["ローディング中", "実行完了" ,"エラー","Waiting","Limited" ,"確認済" ] : ["Loading", "Executed" ,"Error","Waiting","Limited" ,"Confirmed" ]
  
    if(this.isForCar){
      this.listBrands.map((ele,index)=>{
        let count = this.data.filter(val => {
            return (val['result'] && val['result'].hasOwnProperty('brand') && val['result']['brand'] == ele )
        }).length
        let ind =  this.data.findIndex((val)=>{
          return (val['result'] && val['result'].hasOwnProperty('brand') && val['result']['brand'] == ele )
        })
        if(ind > -1){
          let obj = {'name':ele , 'id':null , "count":count}
          this.data.splice( ind, 0, obj );
        }
      })
    }
  },
  mounted() {
    let arrLink = [{'link': '#','name': langChoose =='ja' ?'資料管理' :'Management Document'},{'link': '/listPackage','name':langChoose =='ja' ?'ファイルリスト':'File List'},{'link': '#','name':decodeURI(window.location.pathname.split("/").pop())}]
    updateBreadScrum(arrLink)
    var self = this;
    this.socket = io.connect('/start_processing');

    this.socket.on('connected', function (msg) {
      console.log('After connect', msg);
    });

    this.socket.on('update value', function (msg) {
      $('body').removeClass('loading');
      self.updateValue(msg['data']);
    });
    $(".nicescroll-box").niceScroll(".wrap",{cursorcolor:"#5294B7;"});
    $(".nicescroll-box").mouseover(function() {
      $(".nicescroll-box").getNiceScroll().resize();
    });
    this.initData();
  },
  methods: {
    updateValue: function (msg) {
      if(msg[0].status == 0){
        showAlertCustom("OCR is running..",0)
        this.listIdCheck = []
      }
      for (let i in this.listFilter) {
        for (let y in msg) {
          if (this.listFilter[i].id == msg[y].id) {
            if (this.listFilter[i].id == msg[y].id) {
              if(msg[y].status == 1  && !this.listIdCheck.includes(this.listFilter[i].id)){
                showAlertCustom("File "+ this.listFilter[i].name +" is Excuted",2)
                this.listIdCheck.push(this.listFilter[i].id)
              }else if(msg[y].status ==2 && !this.listIdCheck.includes(this.listFilter[i].id)){
                showAlertCustom("File "+ this.listFilter[i].name +" is Error",3)
                this.listIdCheck.push(this.listFilter[i].id);
              }
              this.listFilter[i].status = msg[y].status;
              this.listFilter[i].result = msg[y].result;
              break;
            }
          }
        }
      }
    },
    dateFilter() {
      var self = this;
      let data = null;
      let dateStart = self.dateFrom != null ? new Date(self.dateFrom) : null;
      let dateEnd = self.dateTo != null ? new Date(self.dateTo + ' 23:59') : null;

      if (dateStart == null && dateEnd != null) {
        data = this.data.filter(function (history) {
          if(history.id==null){ return true;}
          return (new Date(history.created_at) <= dateEnd);
        });
      } else if (dateStart != null && dateEnd == null) {
        data = this.data.filter(function (history) {
          if(history.id==null){ return true;}
          return (new Date(history.created_at) >= dateStart);
        });
      } else if (dateStart != null && this.dateFrom != null) {
        data = this.data.filter(function (history) {
          if(history.id==null){ return true;}
          return (new Date(history.created_at) >= dateStart && new Date(history.created_at) <= dateEnd);
        });
      }
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    categoryFilter() {
      var self = this;
      let data = this.data.filter(function (history) {
        if(history.id==null){ return true;}
        if (self.category.length == 0) {
          return true
        }
        if (!history.type || history.type == null) {
          return false
        }
        return (self.category.indexOf(history.type.toLowerCase()) > -1);
      });
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    brandFilter() {
      var self = this;
      let data = this.data.filter(function (history) {
        if(history.id==null){ return true;}
        if (self.brand_filter.length == 0) {
          return true
        }
        if (!history.result.brand || !history.result.brand == null ) {
          return false
        }
        return (self.brand_filter.indexOf(history.result.brand) > -1);
      });
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    statusFilter() {
      var self = this;
      let data = this.data.filter(function (history) {
        if(history.id==null){ return true;}
        if (self.status_filter.length == 0) {
          return true
        }
        return (self.status_filter.indexOf(history.status) > -1);
      });
      // console.log(self.status_filter)
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    cateSelectAll() {
      this.category = [];
      let data = this.data;
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    statusSelectAll() {
      this.status_filter = [];
      let data = this.data;
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    searchName() {
      var self = this;
      let data = this.data.filter(function (history) {
        if (self.cate_name.length == 0) {
          return true
        }
        return (history.name.toLowerCase().indexOf(self.cate_name.toLowerCase()) > -1);
      });
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.listFilter = this.queryFromVirtualDB(data, startRow, endRow);
    },
    refreshSearchName(){
      this.cate_name = "";
      this.searchName();
    },
     initData: function () {
      var startRow = (this.pageNo - 1) * this.pageSize + 1;
      var endRow = startRow + this.pageSize - 1;
      this.pageCount = Math.ceil(this.data.length / this.pageSize);
      this.listFilter = this.queryFromVirtualDB(this.data, startRow, endRow);
      this.showPage = [];
      if (this.pageCount < 6) {
        for (let i = this.pageNo; i <= this.pageCount; i+= 1 ) {
          this.showPage.push(i);
        }
      } else {
        if (this.pageNo + 3 > this.pageCount) {
          for (let i = this.pageCount - 5; i <= this.pageCount; i+= 1 ) {
            this.showPage.push(i);
          }
        } else if (this.pageNo - 3 <= 0) {
          for (let i = 1; i <= 6; i+= 1 ) {
            this.showPage.push(i);
          }
        } else {
          for (let i = this.pageNo - 3; i <= this.pageNo + 2; i+= 1) {
            this.showPage.push(i);
          }
        }
      }
      let self = this;
      this.allSelected = this.listFilter.every((ele)=>{
        if(ele.id){
          return self.selectedList.includes(ele.id);
        }else{
          return self.listSelectBrand.includes(ele['name']);
        }
      })
    },
    queryFromVirtualDB: function (data, startRow, endRow) {
      var result = [];
      for (var i = startRow - 1; i < endRow; i++) {
        if (i < data.length) {
          result.push(data[i]);
        }
      }
      return result;
    },
    page: function (pageNo) {
      this.pageNo = pageNo;
      this.initData();
    },
    first: function () {
      this.pageNo = 1;
      this.initData();
    },
    last: function () {
      this.pageNo = this.pageCount;
      this.initData();
    },
    prev: function () {
      if (this.pageNo > 1) {
        this.pageNo -= 1;
        this.initData();
      }
    },
    next: function () {
      if (this.pageNo < this.pageCount) {
        this.pageNo += 1;
        this.initData();
      }
    },
    changePagesize: function () {
      if (this.size == -1) {
        this.pageSize = this.data.length
      } else {
        this.pageSize = parseInt(this.size);
      }
      this.pageCount = 0;
      this.pageNo = 1;
      this.initData();
    },
    showStatus(type) {
      if (type == 0) {
        return langChoose =='ja' ? 'ローディング中' :'Loading...'
      } else if (type == 1) {
        return langChoose =='ja' ? '実行完了' :'Executed'
      } else if (type == 2) {
        return langChoose =='ja' ? 'エラー' :'Error'
      } else if (type == 3) {
        return langChoose =='ja' ? 'Waiting' :'Waiting'
      }
      else if (type == 4) {
        return langChoose =='ja' ? 'Limited' :'Limited'
      }
      else if (type == 5) {
        return langChoose =='ja' ? '確認済' :'Confirmed'
      }
    },
    showTemplate(template) {
      if (template == '帳票') {
        return langChoose =='ja' ? '帳票' :'Report'
      } else if (template == 'ナンバープレート') {
        return langChoose =='ja' ? 'ナンバープレート' :'License Plate'
      } else if (template == '運転免許証') {
        return langChoose =='ja' ? '運転免許証' :'Driver License'
      } else if (template == '車検証認識') {
        return langChoose =='ja' ? '車検証認識' :'Vehicle Verification'
      }
      else if (template == 'Unselected') {
        return langChoose =='ja' ? '指定なし' :'Unselected'
      }
      else{
        return template
      }
    },
    selectAll() {
      if (this.allSelected) {
        for (let i in this.listFilter) {
          if(this.listFilter[i].id){
            this.selectedList.push(this.listFilter[i].id);
          }else{
            this.listSelectBrand.push(this.listFilter[i].name)
          }
        }
        this.data.map((ele,ind)=>{
          if(ele['id'] && ele['result'] && ele['result']['brand'] && this.listSelectBrand.includes(ele['result']['brand'])){
            this.selectedList.push(ele['id'])
          }
        });
      } else {
        for (let i in this.listFilter) {
          this.selectedList = this.selectedList.filter((element, index) => {
              return element !== this.listFilter[i].id
          })
          if(this.listFilter[i].id){
            this.listSelectBrand = this.listSelectBrand.filter((element, index) => {
              return  element !== this.listFilter[i].result["brand"]
            })
          }else{
            this.listSelectBrand = this.listSelectBrand.filter((element, index) => {
              return  element !== this.listFilter[i]['name']
            })
          }
          
        }
        $('tr').removeClass('selected');
      }
      this.selectedList = [...new Set(this.selectedList)];
      this.listSelectBrand = [...new Set(this.listSelectBrand)];
    },
    select(id,brand) {
      this.allSelected = false;
      console.log(this.selectedList)

      let check = this.selectedList.includes(id);
      let full = true;
      if(check){
        this.data.map((ele,ind)=>{
          if(ele['result'] && ele['result']['brand'] && ele['result']['brand'] == brand){
            if(this.selectedList.includes(ele['id']) == false){
              full = false;
              return;
            }
          }
        });
        if(full){
          this.listSelectBrand.push(brand)
        }
      }else{
        this.listSelectBrand = this.listSelectBrand.filter(function(item) {
          return item !== brand
        })
      } 
      this.listSelectBrand = [...new Set(this.listSelectBrand)];
    },
    selectBrand(brand) {
      this.allSelected = false;
      console.log(this.listSelectBrand)
      console.log(this.selectedList)
      let check = this.listSelectBrand.includes(brand);
      this.data.map((ele,ind)=>{
        if(ele['result'] && ele['result']['brand'] && ele['result']['brand'] == brand){
          if(check){
            this.selectedList.push(ele.id);
          }else{
            this.selectedList = this.selectedList.filter(function(item) {
              return item !== ele.id
            })
          }
        }
      });
      this.selectedList = [...new Set(this.selectedList)];
      // $('tr').removeClass('selected');
      // this.selectedList.forEach(element => {
      //   $( "#"+element ).addClass( "selected");
      // });
    },
    deleteFile(key){
      this.name_delete ='"'+this.listFilter[key].name + '"'
      this.tmp_key_delete = key;
      this.typedelete = 0;
      $('#alert').modal('toggle');
    },
    deleteSelected(){
      this.name_delete = this.selectedList.length + ' documents'
      this.typedelete = 1;
      $('#alert').modal('toggle');
    },
    confirmDelete() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.reload();
        }
      };
      if(this.typedelete ==1){
        if (this.selectedList.length > 0) {
          $('body').addClass('loading');
          var fd = new FormData();
          fd.append("data", this.selectedList);
          xhr.open("POST", "/delete_result", true);
          xhr.send(fd);
        }
      }else if(this.typedelete ==0){
        let lisTmp = [] 
        lisTmp.push(this.listFilter[this.tmp_key_delete].id);
        if (lisTmp.length > 0) {
          $('body').addClass('loading');
          var fd = new FormData();
          fd.append("data", lisTmp);
          xhr.open("POST", "/delete_result", true);
          xhr.send(fd);
        }
      }
    },
    saveBlob(blob, fileName) {
      var a = document.createElement('a');
      a.href = window.URL.createObjectURL(blob);
      a.download = fileName;
      a.dispatchEvent(new MouseEvent('click'));
    },
    checkFormat(type) {
      for (let x of this.formats) {
        if (type == x.name) {
          return true
        }
      }
      return false
    },
    reRunOCR(key) {
      let datas = {};
      if (key) {
        datas[this.listFilter[key].id] = this.listFilter[key].type;
      } else {
        for (const dataItem of this.data)
        for (const selectedItem of this.selectedList) {
          if (dataItem.id == selectedItem) datas[selectedItem] = dataItem.type;
        }
      }
      console.log(datas);
      var self = this;
      self.socket = io.connect('/start_processing');
      self.socket.on('connected', function (msg) {
      console.log('After connect', msg);
      self.socket.emit('process', {data: datas});
      });
    },
    exportDataByKey(key) {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
        let data = JSON.parse(this.response);
        let a = document.createElement("a");
        a.style = "display: none";
        document.body.appendChild(a);
        a.href = data.path;
        a.download = data.path.split('/').pop();
        a.click();
      };
      let lisTmp = []
      lisTmp.push(this.listFilter[key].id);
      if (lisTmp.length > 0) {
        $('body').addClass('loading');
        var fd = new FormData();
        fd.append("data", lisTmp);
        xhr.open("POST", "/export_multiple", true);
        xhr.send(fd);
      }
    },
    exportData() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
        let data = JSON.parse(this.response);
        let a = document.createElement("a");
        a.style = "display: none";
        document.body.appendChild(a);
        a.href = data.path;
        a.download = data.path.split('/').pop();
        a.click();
      };
      if (this.selectedList.length > 0) {
        $('body').addClass('loading');
        var fd = new FormData();
        fd.append("data", this.selectedList);
        xhr.open("POST", "/export_multiple", true);
        xhr.send(fd);
      }
    },
    prettyDate: function (date) {
      let pad = function (val, len) {
        val = String(val);
        len = len || 2;
        while (val.length < len) val = "0" + val;
        return val;
      };
      let a = new Date(date);
      return a.getFullYear() + "/" + pad(a.getMonth() + 1) + "/" + pad(a.getDate()) + ' ' + pad(a.getHours()) + ':' + pad(a.getMinutes()) + ':' + pad(a.getSeconds());
    },
    getType: function (id) {
      for (let x of this.data) {
        if (x.id == id) {
          return x.type
        }
      }
      return null
    },
    markError(id, error) {
      for (let i in this.listFilter) {
        if (this.listFilter[i].id == id) {
          this.listFilter[i].error = error
        }
      }
    },
    startProcess: function () {
      if (this.selectedList.length > 0) {
        let error = false;
        let data = {};
        for (let x of this.selectedList) {
          data[x] = this.getType(x);
          // if (data[x] == null) {
          //   this.markError(x, true);
          //   error = true;
          // } else {
          //   this.markError(x, false)
          // }
        }
        if (!error) {
          console.log()
          $('body').addClass('loading');
          this.socket.emit('process', {data: data});
        } else {
          $('#alert').modal('toggle');
        }
      }
    },
    selectFile() {
      $('#files').click();
    },
    handleFilesUpload() {
      this.files = this.$refs.files.files;
      if(this.files.length > 10){
        showAlertCustom("File upload quantity must be less than 10!",3)
        this.clear()
        return;
      }
      for (var i = 0; i < this.files.length; i++) {
        if (this.files[i].type.match('image.*') || this.files[i].type.match('application/pdf')) {
          let data = {
            'file': this.files[i],
            'url': URL.createObjectURL(this.files[i]),
            'type': this.default_type,
            'name': this.files[i].name,
            'edit': false  
          };
          this.listFile.push(data);
        }
      }
      
      if(this.listFile.length == 1){
        this.name_upload = this.listFile[0]['name'];
      }else{
        this.name_upload = this.listFile.length + ' documents';
      }

      $('#upload_modal').modal('toggle');
    },
    clear() {
      this.listFile = [];
      $("#files").val('');
      
    },
    submitFiles() {
      var formData = new FormData();
      formData.append("packageName",this.folderName)
      for (let i in this.listFile) {
        formData.append("img_data[]", this.listFile[i].file);
        formData.append("type_img_" + i, this.listFile[i].type != null ? this.listFile[i].type : '');
        formData.append("name_" + i, this.listFile[i].name);
      }
      $('body').addClass("loading");
      $.ajax({
        url: window.location.pathname,
        type: "POST",
        data: formData,
        mimeTypes: "multipart/form-data",
        contentType: false,
        processData: false,
        success: function (res) {
          console.log(res)
          if(res['mess']=='success'){
            $('body').removeClass("loading");
            window.location.reload();
          }
        }, error: function () {
          $('body').removeClass("loading");
          alert('トライアル範囲を超えました。担当者にご連絡お願い致します。')
        }
      });
    },  
  }
});