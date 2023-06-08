myObject = new Vue({
  el: '#upload',
  data: {
    list: [],
    formats: [],
    subforms: [],
    default_type: null,
    files: null,
    editedTodo: null,
    nameInput: null,
    folderName: null,
    textSearch: null,
    ind_delete: null,
    name_delete: null,
    isNiceScroll: false
  },
  beforeMount: function () {
    this.formats = localData.form || [];
    this.subforms = localData.subforms || [];

    if (this.formats != null || this.formats.length > 0) {
       this.default_type = this.formats.id;
    }
  },
  updated() {
    if(this.folderName && this.isNiceScroll==false){
      $(".nicescroll-box").niceScroll(".wrap",{cursorcolor:"#5294B7;"});
      $(".nicescroll-box").getNiceScroll().resize();
      console.log("updated");
      this.isNiceScroll = true;
    }

  },
  mounted() {
    let type = arrLanguage[langChoose][window.location.pathname.split("/").pop()];;
    let arrLink = [{'link': '/','name': langChoose =='ja' ? 'AIME-OCRダッシュボード' :'AIME-OC Dashboard' },{'link': '#','name':type}]
    updateBreadScrum(arrLink)
  },
  methods: {    
    selectFile() {
      $('#files').click();
    },
    selectDefault(type) {
      this.default_type = type.id
    },
    fileDragHover(e) {
      var fileDrag = document.getElementById('upload-content');
      e.stopPropagation();
      e.preventDefault();
      fileDrag.className = (e.type === 'dragover' ? 'hover' : 'card-body');
    },
    deleteImg(index,name){
      this.ind_delete = index;
      this.name_delete = name;
      $("#exampleModalCenter").modal('toggle');
    },
    ConfirmDeleteImg() {
      this.list.splice(this.ind_delete, 1);
      showAlertCustom(langChoose =='ja' ?"削除に成功！" :"Delete Successful!",2);
      if(!this.list.some(ele => ele.name.includes(this.textSearch))){
        this.refreshSearch();
      }
      if(this.list.length == 0){
        $("#files").val('');
        this.folderName = null;
      }
      $("#exampleModalCenter").modal('toggle');
      this.isNiceScroll=false
    },
    showFilterCount(){
      let count = 0;
      this.list.forEach(f => {
        if(f.name.includes(this.textSearch)){
          count++;
        } 
      });
      return count;
    }
    ,
    fileDropHover(e) {
      var fileDrag = document.getElementById('upload-content');
      fileDrag.className = 'card-body';
      let droppedFiles = e.dataTransfer.files;
      if(droppedFiles.length > 10){
        this.showNotice(langChoose =='ja' ?"ファイルアップロード数は10！" :"File upload quantity must be less than 10!",3)
        this.clear()
        return;
      }
      if (!droppedFiles) return;
      ([...droppedFiles]).forEach(f => {
        if (f.type.match('image.*') || f.type.match('application/pdf')) {
          let data = {
            'file': f,
            'url': URL.createObjectURL(f),
            'type': this.default_type,
            'name': f.name,
            'edit': false
          };
          this.list.push(data);
        }
      });
      $("#create-folder").modal('toggle');
      
    },
    editTodo: function (todo) {
      this.list = todo;
    },
    handleFilesUpload() {
      this.files = this.$refs.files.files;
      if(this.files.length > 10){
        this.showNotice(langChoose =='ja' ?"ファイルアップロード数は10！" :"File upload quantity must be less than 10!",3)
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
          this.list.push(data);
        }
      }
      $("#create-folder").modal('toggle');

    },
    createFolder(res) {
      if(res["message"] === "success"){
        this.folderName = this.nameInput;
        $("#create-folder").modal('toggle');
        $("#files").val('');
        this.nameInput = null;
        let type = arrLanguage[langChoose][window.location.pathname.split("/").pop()];;
        let arrLink = [{'link': '/','name': langChoose =='ja' ? 'AIME-OCRダッシュボード' :'AIME-OC Dashboard' },{'link': '#','name':type},{'link': '#','name':this.folderName}]
        updateBreadScrum(arrLink)
        this.showNotice(langChoose =='ja' ?"フォルダーが作成されました。!" : "Create Folder Sucessfully!" ,2)
      }
      else{
        this.showNotice( langChoose =='ja'  ? "同じ名前のフォルダーが既にあります。!":"Folder's name has already Exists!",3)
      }
    },
    checkFolder(createFolder ,showNotice) {
      if(this.nameInput =='' || this.nameInput == null){
        this.showNotice( langChoose =='ja'  ? "フォルダー名を空にすることは出来ません。":"Folder Name can not be Empty!",3)
        return;
      }
      var formData = new FormData();
      formData.append("packageName",this.nameInput)
      $('body').addClass("loading");
      $.ajax({
        url: "/checkPackage",
        type: "POST",
        data: formData,
        mimeTypes: "multipart/form-data",
        contentType: false,
        processData: false,
        success: function (res) {
          $('body').removeClass("loading");
          console.log(res);
          createFolder(res);
        }, error: function () {
          $('body').removeClass("loading");
          showNotice("loi request",3)
        }
      });
    },
    refreshSearch(){
      this.textSearch = null;
      $(".nicescroll-box").getNiceScroll().resize();
    },
    searchClick(){
      if(!this.textSearch){
        showAlertCustom( langChoose =='ja'  ? "検索のためにドキュメントの名前をインプットバーにご入力ください":"Please enter document's name to the input bar to search!",1);
      }
    }
    ,
    showNotice(msg,type){
      showAlertCustom(msg,type);
    }
    ,
    clear() {
      this.list = [];
      $("#files").val('');
      this.folderName = null;
    },
    showTemplate(template) {
      if (this.formats.name) {
        return this.formats.name
      }
      else{
        return template
      }
    },
    submitFiles(pack_id) {
      var formData = new FormData();
      formData.append("packageName",this.folderName)
      for (let i in this.list) {
        formData.append("img_data[]", this.list[i].file);
        formData.append("type_img_" + i, this.list[i].type != null ? this.list[i].type : '');
        formData.append("name_" + i, this.list[i].name);
      }
      $('body').addClass("loading");
      $.ajax({
        url: "/upload",
        type: "POST",
        data: formData,
        mimeTypes: "multipart/form-data",
        contentType: false,
        processData: false,
        success: function (res) {
          $('body').removeClass("loading");
          window.location.replace('/review?id='+res['pack_id'])
        }, 
        error: function () {
          $('body').removeClass("loading");
          alert('トライアル範囲を超えました。担当者にご連絡お願い致します。')
        }
      });
    }
  }
});