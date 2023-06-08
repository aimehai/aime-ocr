resultComponent = new Vue({
  el: '#review',
  data: {
    additional_data: [],
    files: null,
    data: [],
    number_confirmed: 0,
    name_delete: '',
    displayfilter : [],
    msgNotice:null,
    showNotice : false,
    hiddenRect : {},
    current: 0,
    socket: null,
    data_reduce: [],
    rect: {},
    is_cv2_drawed: false,
    zoomLevel: 1,
    listIdCheck: [],
    extractData: {},
    showLine : false,
    current_key_ind: null,
    showData: 0,
    tmp_key_delete: null,
    fileID: null
  },
  updated: function () {
    self = this;
    this.$nextTick(function () {
      if( self.is_cv2_drawed == false && $("#canvas-small"+(self.rect.labels.length -1))[0]){
        $(".nicescroll-key").niceScroll();
        let index =0 ;
        for (let a of self.rect.labels) {
          self.rect.drawCropped($("#canvas-small"+index)[0] , a )
          index++;
        }
        $(".nicescroll-box").getNiceScroll().resize();
        self.is_cv2_drawed = true;
       }
    })
  },
  beforeMount: function () {
    this.data = localData.data;
    var url = window.location.href;
    url = new URL(url);
    var c = url.searchParams.get("id");
    let id = 0;
    if (c && c != null) {
      this.fileID = c;
    }
    let result = this.data[id]['result'];

    if(result){
      console.log(result)
      this.currentExtract = result['extracted'];
      console.log(this.currentExtract)
      Object.keys( this.currentExtract).map((ele,index)=>{
        this.displayfilter[ele] = true;
      });
    }

    let confirm = 0;
    this.data.forEach(element => {
      if(element.status== 5){
        confirm++;
      }
    });
    this.number_confirmed = confirm;
  },
  mounted() {
    $('#bread-scrum').hide()
    let url = window.location.href;
    url = new URL(url);
    let c = url.searchParams.get("id");
    let arrLink = [{'link': '#','name':'Reviewing'},{'link': '#','name':c}]
    // this.updateBreadScrum(arrLink)
    var self = this;
    self.socket = io.connect('/start_processing');

    self.socket.on('update value', function (msg) {
      // $('body').removeClass('loading');
      console.log(msg);
      self.updateValue(msg['data']);
    });
    self.socket.on('connected', function (msg) {
      let datas = {};
      self.data.forEach((element,ind) => {
        if(element.status == 3){
          datas[element.id] = element.type;
        }
        
      });
      self.socket.emit('process', {data: datas});
    });


    $(".nicescroll-box").niceScroll(".wrap",{cursorcolor:"#5294B7;",touchbehavior:true});
    $(".nicescroll-box-file").niceScroll(".wrap",{cursorcolor:"#5294B7;",touchbehavior:true});

    $(".nicescroll-box").mouseover(function() {
      $(".nicescroll-box").getNiceScroll().resize();
    });
    $( ".nicescroll-box" ).scroll(function() {
      self.updateLine();
      $( ".nicescroll-key" ).getNiceScroll().resize();
    });
    $(".owl-carousel").owlCarousel({
      startPosition: self.current != null ? self.current : 0
    });
    // $(".am-next").click(function () {
    //   $(".owl-carousel").trigger('next.owl.carousel');
    // });
    // $(".am-prev").click(function () {
    //   $(".owl-carousel").trigger('prev.owl.carousel');
    // });

    var wi = $("#canvasContainer")[0].offsetWidth //400;
    var h = $("#canvasContainer")[0].offsetHeight //500;
    if (window.screen.width < 1250) {
      wi = 300;
      h = 400;
    }
    var canvas = new fabric.Canvas('canvas', {
      width: wi, height: h
    });
    let cropped = $('#canvas2')[0];
    if(self.data[self.current].type === "帳票"){
      if(self.data[self.current]['raw_path'] != null && self.data[self.current]['raw_path'] != ''){
        self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,false);
      }
    }
    else if(self.data[self.current].type ==="車検証認識"){
      if(self.data[self.current]['output_path'] != null && self.data[self.current]['output_path'] != ''){
        self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['output_path'], cropped,false);
      }
      else{
        self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,false);
      }
    }else {
      self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,false);
    }

    $('.buttonfile').removeClass('selected')
    $('#file'+this.current).addClass('selected')
    $('.result-file-status').removeClass('selected')
    $('#status'+this.current).addClass('selected')
    $('[id^="pname-"]').removeClass('selected')
    $('#pname-'+this.current).addClass('selected')
    this.rect.boxScaling = function (transform) {
      // console.log("saclaii "+pointer);
      self.updateLine2(transform.target);
    } 
    this.rect.drawSuccess = function () {
      if (self.data[self.current]['result'] != null) {
        self.data[self.current]['result'] = self.data[self.current]['result']
      }
      if (self.data[self.current]['format'] && self.data[self.current]['format'] != null) {
        let list = self.data[self.current]['format'];
        for (let x of list['results']) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, null, null, x['columns'], x['rows'], x['key'], x['details'], x['position']);
        }
        if (self.data[self.current]['result'] != null) {
          self.extractData = self.data[self.current]['result']['extracted'];
        }
      } else if (self.data[self.current]['result']['extracted'] != null) {
        self.extractData = self.data[self.current]['result']['extracted'];
        if (self.data[self.current]['result']['raw']['size_w']) {
          let size_w = self.data[self.current]['result']['raw']['size_w'];
          let size_h = self.data[self.current]['result']['raw']['size_h'];
          let list = self.data[self.current]['result']['extracted'];
          let labels = [];
          for (let x in list) {
            for (let y of list[x][0]) {
              y['key'] = x;
              labels.push(y)
            }
          }
          console.log("AAAAAA");
          console.log(labels);
          for (let x of labels) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, size_w, size_h, x['text'], 1, 1, x['key']);
          }
        } else {
          self.extractData = self.convertDatav2(self.data[self.current]['result']['extracted']);
        }
      } else if (self.data[self.current]['result']) {
        let list = self.data[self.current]['result']['raw']['result'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        self.extractData = self.convertData(list);
        for (let x of list) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, size_w, size_h, x['text'], 1, 1, x['id']);
        }
      }
      for (let x of self.rect.labels) {
        x.selectable = true;
        x.selection = true;
      }

    };
    this.rect.boxChanging = function () {
      self.updateLine();
    }
    this.rect.afterModified = function() {
      let square = self.rect.canvas.getActiveObject();
      // console.log(Math.round(square.top/square.scale)  + " left"+Math.round(square.left/square.scale)+" w: "+Math.round(square.width/square.scale) +" h:"+Math.round(square.height/square.scale));
      let left = Math.round(square.left/square.scale)
      let top = Math.round(square.top/square.scale)
      let w = Math.round(square.width/square.scale)
      let h = Math.round(square.height/square.scale)
      for (let x in self.extractData ) {
          if(square.key == x){
            // console.log(self.extractData[x]);
            self.data[self.current]['result']['extracted'][x][0][0]["x"] = left;
            self.data[self.current]['result']['extracted'][x][0][0]["y"] = top;
            self.data[self.current]['result']['extracted'][x][0][0]["w"] = w;
            self.data[self.current]['result']['extracted'][x][0][0]["h"] = h;
          }
      }
      self.updateLine()
    }
    this.rect.callBack = function () {
      let rec = self.rect.canvas.getActiveObject();
      let key = rec['key'];
      let ind = Object.keys(self.extractData).indexOf(key.toString());
      $('.data-div').removeClass('selected');
      $('#data-extract'+ind).addClass('selected')

      let docViewTop =$("#top-scroll").offset().top + $("#top-scroll").height()
      let docViewBottom = $("#bottom-scroll").offset().top;

      let elemTop = $('#data-extract'+ind).offset().top + $('#data-extract'+ind).height()/2
      // let point = {}
      console.log($('#data-extract'+ind).position().top +" off: "+ $('#data-extract'+ind).offset().top);
      if(elemTop > docViewBottom){
        //sth
        $(".nicescroll-box").getNiceScroll(0).doScrollTop($('#data-extract'+ind).position().top - $('#data-extract'+ind).height(), 1);
      }else if(elemTop < docViewTop){
        //do scroll
        $(".nicescroll-box").getNiceScroll(0).doScrollTop($('#data-extract'+ind).position().top , 1);
      }
      //draw line
      self.current_key_ind = ind;
      self.updateLine()
    }
  },
  methods: {
    updateValue: function (msg) {
      console.log(msg)
      if(msg.some((element) => element.status == 0)){
        showAlertCustom( langChoose =='ja' ?"ＯＣＲが実行中..":"OCR is running..",0)
        this.listIdCheck = []
      }
      let tmp = []
      this.data.forEach( (val,ind)=>{
        for (let y in msg) {
          if (val.id == msg[y].id) {
            if(msg[y].status == 1 && !this.listIdCheck.includes(val.id)){
              showAlertCustom((langChoose =='ja' ? "ドキュメント#":"File ")+ val.name +(langChoose =='ja' ? "が実行完了となります。":" is Executed"),2)
              this.listIdCheck.push(val.id)
            }else if(msg[y].status ==2 && !this.listIdCheck.includes(val.id)){
              showAlertCustom( (langChoose =='ja' ? "ドキュメント#":"File ")+ val.name +(langChoose =='ja' ? "がエラーとなります。":" is Error"),3)
              this.listIdCheck.push(val.id)
            }
            this.data[ind].status = msg[y].status;
            this.data[ind].result = msg[y].result;
            this.data[ind]['output_path'] = msg[y].output_path;
            tmp.push(ind)
            break;
          }
        }
      });
      // this.$forceUpdate();
      $('#status'+this.current).addClass('selected')

      if(this.data[this.current].status == 1 && tmp.includes(this.current) && this.data[this.current]["result"].hasOwnProperty("extracted")){
        this.selectDocument(this.current)
      }
    },
    convertData(data) {
      var res = {};
      for (let d of data) {
        res[d['id']] = [[d]]
      }
      return res
    },
    convertDatav2(data) {
      var res = {};
      for (let d of Object.keys(data)) {
        res[d] = [[{
          'text': data[d]
        }]]
      }
      return res
    },
    updateBreadScrum(arr){
      arr.forEach((element,ind) => {
        if(ind == (arr.length-1)){
          let li_html ='<li class="breadcrumb-item active " aria-current="page">'+ element['name'] +'</li>'
          $("#bread-scrum-ol-super").append(li_html);
        }else{
          let li_html ='<li class="breadcrumb-item "><a href="'+ element['link'] +'">'+ element['name'] +'</a></li>'
          $("#bread-scrum-ol-super").append(li_html);
        }
      })
    },
    reDraw() {
      this.showData = this.showData === 0 ? 1 : 0;
      this.rect.clearLabel();
      var self = this;
      if (this.showData === 1) {
        self.extractData = self.convertData(self.data[self.current]['result']['raw']['result']);
        let list = self.data[self.current]['result']['raw']['result'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        for (let x of list) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], size_w, size_h, x['text'], 1, 1, x['id']);
        }
      } else {
        self.extractData = self.data[self.current]['result']['extracted'];
        if (self.data[self.current]['format'] && self.data[self.current]['format'] != null) {
          let list = self.data[self.current]['format'];
          for (let x of list['results']) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, null, x['columns'], x['rows'], x['key'], x['details'], x['position']);
          }
        } else if (self.data[self.current]['result']['extracted'] != null) {
          let list = self.data[self.current]['result']['extracted'];
          let labels = [];
          for (let x in list) {
            for (let y of list[x][0]) {
              labels.push({...y, key: x})
            }
          }
          for (let x of labels) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, x['text'], 1, 1, x['key']);
          }
        }
      }
    },
    backToFileList(){
      const params = new URLSearchParams(window.location.search);
      const pack_id = params.get('id')
      window.location.replace('/listPackage/'+ pack_id)
       
    },
    selectDocument(id){
      $('.buttonfile').removeClass('selected')
      $('#file'+id).addClass('selected')
      $('.result-file-status').removeClass('selected')
      $('#status'+id).addClass('selected')
      $('[id^="pname-"]').removeClass('selected')
      $('#pname-'+id).addClass('selected')
      this.current = id;
      // this.reDraw();
      this.displayfilter = {}
      this.extractData = {}
      this.hiddenRect = {}
      this.rect.canvas.clear()
      this.rect.canvas.dispose()
      this.is_cv2_drawed = false;
      this.showNotice = false;
      this.showLine = false;
      this.current_key_ind = null;

      console.log("current")
      console.log(this.data[id])
      let result = this.data[id]['result'];

      if(result){
        this.currentExtract = result['extracted'];
        console.log(this.currentExtract)
        if(this.currentExtract){
          Object.keys(this.currentExtract).map((ele,idx) =>{
            this.displayfilter[ele] = true;
          });
        }

      }


      this.mountAgain();
    }
    ,
    selectRect(key,ind, e) {
      let rectCanvas = null;
      for (let a of this.rect.labels) {
        if (a['key'] == key) {
          rectCanvas = a;
          break;
        }
      }
      this.rect.selectObj(rectCanvas);
      $('.data-div').removeClass('selected');
      $('#data-extract'+ind).addClass('selected')
      // this.rect.canvas.setActiveObject(null);
      this.current_key_ind = ind;
      this.updateLine()
      // this.drawLine(x,ind)

    },
    selectRectInput(key,ind, e) {
      this.current_key_ind = ind;
      let x = null;
      for (let a of this.rect.labels) {
        if (a['key'] == key) {
          x = a;
          break;
        }
      }
      this.rect.selectObj(x);
      $('.data-div').removeClass('selected');
      // $(e.target).parent('div').parent('div').parent("div").addClass('active')
      $('#data-extract'+ind).addClass('selected')
      // this.rect.canvas.setActiveObject(null);
      // this.drawLine(x,ind)
      this.current_key_ind = ind;
      this.updateLine()
    },

    showKeyVal: function () {
      if (this.data[this.current]['result']['extracted'] != null) {
        $('#show-table').modal('toggle');
      }
    },
    removeLabel(key,ind, e) {
      if(this.current_key_ind == ind){
        this.showLine = false;
        this.current_key_ind = null;
        this.updateLine()
      }
      if(this.displayfilter[key]){
        this.displayfilter[key] = false
        let f = this.rect.labels.find(rec => rec['key'] == key);
        this.hiddenRect[key] = f
        this.rect.removeLabel(f);
      }else{
        this.displayfilter[key] = true;
        let f =  this.hiddenRect[key]
        this.rect.showLabel(f)
        delete this.hiddenRect[key]
      }
      // delete this.data[this.current]['result']['extracted'][key];
      // this.rect.canvas.setActiveObject(null);
      this.$forceUpdate();
    },
    deleteFile(id){
      this.name_delete ='"'+this.data[id].name + '"'
      this.tmp_key_delete = id;
      $("#custom-line").css({"width": "0px"});
      $('#alert').modal('toggle');
    },
    confirmDeleteFile() {
      let self = this;
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          if(self.data.length <= 1){
            window.location.replace("/")
          }else{
            window.location.reload();
          }
        }
      };
      let lisTmp = [] 
      lisTmp.push(self.data[self.tmp_key_delete].id);
      if (lisTmp.length > 0) {
        $('body').addClass('loading');
        var fd = new FormData();
        fd.append("data", lisTmp);
        xhr.open("POST", "/delete_result", true);
        xhr.send(fd);
      }

    }
    ,
    updateStatus() {
      if (this.data[this.current]['view_status'] != true) {
        var xhr = new XMLHttpRequest();
        xhr.onload = function () {
          if (this.status == 200) {
            console.log('success');
          }
        };
        var fd = new FormData();
        fd.append("id", this.data[this.current]['id']);
        xhr.open("POST", "/update_view_status", true);
        xhr.send(fd);
      }
    },
    zoomIn(){
      let point = new fabric.Point(this.rect.canvas.width/2, this.rect.canvas.height/2);
      this.rect.zoomIn(point);
    },
    zoomOut(){
      let point = new fabric.Point(this.rect.canvas.width/2, this.rect.canvas.height/2);
      this.rect.zoomOut(point);
    },
    resetZoom(){
      let point = new fabric.Point(this.rect.canvas.width/2, this.rect.canvas.height/2);
      this.rect.resetZoom(point);
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
    // resetzoom(){
    //   this.rect.canvas.setHeight(canvas.getHeight() /canvas.getZoom() );
    //   this.rect.canvas.setWidth(canvas.getWidth() / canvas.getZoom() );
    //   this.rect.canvas.setZoom(1);
  
    //   this.rect.canvas.renderAll();
    // }
    // ,
    updateExport() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
        let data =this.response;
        let a = document.createElement("a");
        a.style = "display: none";
        document.body.appendChild(a);
        a.href = data.path;
        a.download = data.path.split('/').pop();
        a.click();
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("id", this.data[this.current]['id']);
      xhr.open("POST", "/exportv3", true);
      xhr.send(fd);
    },
    saveData() {
      let data = [];
      let zoom = this.rect.getScale();
      for (let lab of this.rect.labels) {
        let d = {
          'x': Math.round(lab.left / zoom),
          'y': Math.round(lab.top / zoom),
          'w': Math.round(lab.width / zoom),
          'h': Math.round(lab.height / zoom),
          'text': lab.text
        };
        data.push(d);
      }

      this.data[this.current]['result']['raw']['result'] = data;
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("data", JSON.stringify(this.data[this.current]['result']));
      fd.append("id", this.data[this.current]['id']);
      xhr.open("POST", "/save", true);
      xhr.send(fd);
    },
    prettyDate: function (date) {
      let pad = function (val, len) {
        val = String(val);
        len = len || 2;
        while (val.length < len) val = "0" + val;
        return val;
      };
      let a = new Date(date);
      return a.getFullYear() + "/" + pad(a.getMonth() + 1) + "/" + pad(a.getDate()) + ' ' + pad(a.getHours()) + ':' + pad(a.getMinutes());
    },
    // nextImg() {
    //   if (this.current < this.data.length - 1) {
    //     this.current += 1;
    //   }
    // },
    // prevImg() {
    //   if (this.current > 0) {
    //     this.current -= 1;
    //   }
    // },
    // selectImg(id) {
    //   this.current = id;
    //   window.location.replace('/result?id=' + this.data[this.current].id);
    // },
    // redirect(url) {
    //   window.location.replace(url)
    // },
    // showImg(src) {
    //   $('#imagemodal').modal('show');
    //   var self = this;
    //   var zX = self.zoomLevel;
    //   $('.imagepreview').attr('src', src);
    //   $('#imagemodal .modal-dialog').bind('mousewheel', function (e) {
    //     var dir = 0;
    //     if (e.originalEvent.wheelDelta > 0) {
    //       dir += 0.1;
    //     } else {
    //       dir -= 0.1;
    //     }
    //     self.zoomLevel += dir;
    //     if (self.zoomLevel < 4 && self.zoomLevel >= 1) {
    //       $(this).css('transform', 'scale(' + self.zoomLevel + ')');
    //     } else if (self.zoomLevel >= 4) {
    //       self.zoomLevel = 4;
    //     } else {
    //       self.zoomLevel = 1;
    //     }
    //   });
    // },
    // showSVG() {
    //   $('#show-svg .modal-body').empty();
    //   let txt = $('#draw-content').html();
    //   let wd = $('#draw-content').width();

    //   $('#show-svg .modal-body').append(txt);
    //   $('#show-svg').modal('show');
    //   var self = this;
    //   $('#show-svg .modal-content').width(wd + 50);
    //   $('#show-svg').bind('mousewheel', function (e) {
    //     var dir = 0;
    //     if (e.originalEvent.wheelDelta > 0) {
    //       dir += 0.1;
    //     } else {
    //       dir -= 0.1;
    //     }
    //     self.zoomLevel += dir;
    //     if (self.zoomLevel < 4.0 && self.zoomLevel >= 1) {
    //       $(this).css('transform', 'scale(' + self.zoomLevel + ')');
    //     } else if (self.zoomLevel >= 4.0) {
    //       self.zoomLevel = 4.0;
    //     } else {
    //       self.zoomLevel = 1;
    //     }
    //   });
    // },
    // drawSvg() {
    //   function text(data, scale) {
    //     let html = "";
    //     let pad = 0;
    //     for (let i in data.result) {
    //       let t = data.result[i];
    //       let font_size = t.direction == "vert" ? parseInt(t.w * scale / 1.3) : parseInt(t.h * scale / 1.3);
    //       if (parseInt(t.y) < parseInt(t.h) && t.direction == "horiz")
    //         pad = parseInt(t.h - t.y);
    //       html += '<text x="' + parseInt(parseInt(t.x) * scale) + '" y="' + parseInt(parseInt(t.y + pad) * scale) + '" width="' + parseInt(parseInt(t.w) * scale) + '" height="' + parseInt(parseInt(t.h) * scale) + '" font-size="' + (font_size) + '"' + (t.direction == "vert" ? 'transform="rotate(90 ' + parseInt(parseInt(t.x) * scale) + ', ' + parseInt(parseInt(t.y + pad) * scale) + ')"' : '') + '">' + t.text + '</text>'
    //     }
    //     return html;
    //   }

    //   $('#draw-content').html('');
    //   if (this.data[this.current]['result'] != null) {
    //     let data = this.data[this.current]['result']['raw'];
    //     let w = $('#draw-content').width();
    //     let per = w / data.size_w;
    //     per = per > 1 ? 1 : per;
    //     let html = '<svg  style="background-color: #ffffff" width="' + w + '" height="' + (parseInt(data.size_h * per)) + '">' +
    //         text(data, per);
    //     '</svg>'
    //     $('#draw-content').append(html);
    //   }
    // },
    mountAgain(){
    
    var self = this;
    console.log(self.data)

    var wi = $("#canvasContainer")[0].offsetWidth //400;
    var h = $("#canvasContainer")[0].offsetHeight //500;
    if (window.screen.width < 1250) {
      wi = 300;
      h = 400;
    }
    var canvas = new fabric.Canvas('canvas', {
      width: wi, height: h
    });
    let cropped = document.getElementById('canvas2')
    
    if(self.data[self.current].type === "帳票"){
      if(self.data[self.current]['raw_path'] != null && self.data[self.current]['raw_path'] != ''){
        self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,false);
        console.log("here1")
      }
    }
    else if(self.data[self.current].type ==="車検証認識"){
      if(self.data[self.current]['output_path'] != null && self.data[self.current]['output_path'] != ''){
        self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['output_path'], cropped,false);
        console.log("here2")
      }
      else{
        self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,false);
        console.log("here3")
      }
    }else {
      self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,false);
      console.log("here4")
    }
    
    this.rect.drawSuccess = function () {
      if (self.data[self.current]['result'] != null) {
        self.data[self.current]['result'] = self.data[self.current]['result']
      }
      if (self.data[self.current]['format'] && self.data[self.current]['format'] != null) {
        let list = self.data[self.current]['format'];
        for (let x of list['results']) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, null, null, null, x['columns'], x['rows'], x['key'], x['details'], x['position']);
        }
        if (self.data[self.current]['result'] != null) {
          self.extractData = self.data[self.current]['result']['extracted'];
        }
      } else if (self.data[self.current]['result'] && self.data[self.current]['result']['extracted'] != null) {
        self.extractData = self.data[self.current]['result']['extracted'];
        if (self.data[self.current]['result']['raw']['size_w']) {
          let size_w = self.data[self.current]['result']['raw']['size_w'];
          let size_h = self.data[self.current]['result']['raw']['size_h'];
          let list = self.data[self.current]['result']['extracted'];
          let labels = [];
          for (let x in list) {
            console.log(x);
            for (let y of list[x][0]) {
              y['key'] = x;
              labels.push(y)
            }
          }
          for (let x of labels) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, size_w, size_h, x['text'], 1, 1, x['key']);
          }
        } else {
          self.extractData = self.convertDatav2(self.data[self.current]['result']['extracted']);
        }
      } else if (self.data[self.current]['result']) {
        let list = self.data[self.current]['result']['raw']['result'];
        let size_w = self.data[self.current]['result']['raw']['size_w'];
        let size_h = self.data[self.current]['result']['raw']['size_h'];
        self.extractData = self.convertData(list);
        for (let x of list) {
          self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], null, size_w, size_h, x['text'], 1, 1, x['id']);
        }
      }
      for (let x of self.rect.labels) {
        x.selectable = true;
        x.selection = true;
      }
    };
    this.rect.boxScaling = function (transform) {
      // console.log("saclaii "+pointer);
      self.updateLine2(transform.target);
    };
    this.rect.boxChanging = function () {
      self.updateLine();
    }
    this.rect.afterModified = function() {
      let square = self.rect.canvas.getActiveObject();
      // console.log(Math.round(square.top/square.scale)  + " left"+Math.round(square.left/square.scale)+" w: "+Math.round(square.width/square.scale) +" h:"+Math.round(square.height/square.scale));
      let left = Math.round(square.left/square.scale)
      let top = Math.round(square.top/square.scale)
      let w = Math.round(square.width/square.scale)
      let h = Math.round(square.height/square.scale)
      for (let x in self.extractData ) {
          if(square.key == x){
            // console.log(self.extractData[x]);
            self.data[self.current]['result']['extracted'][x][0][0]["x"] = left;
            self.data[self.current]['result']['extracted'][x][0][0]["y"] = top;
            self.data[self.current]['result']['extracted'][x][0][0]["w"] = w;
            self.data[self.current]['result']['extracted'][x][0][0]["h"] = h;
          }
      }
      self.updateLine();
    }
    this.rect.callBack = function () {
        let rec = self.rect.canvas.getActiveObject();
        let key = rec['key'];
        let ind = Object.keys(self.extractData).indexOf(key.toString());
        console.log(Object.keys(self.extractData))
        console.log(key +" ind " +ind);
        $('.data-div').removeClass('selected');
        $('#data-extract'+ind).addClass('selected')


        let docViewTop =$("#top-scroll").offset().top + $("#top-scroll").height()
        let docViewBottom = $("#bottom-scroll").offset().top;
        let elemTop = $('#data-extract'+ind).offset().top + $('#data-extract'+ind).height()/2
        // let point = {}
        console.log($('#data-extract'+ind).position().top +" off: "+ $('#data-extract'+ind).offset().top);
        if(elemTop > docViewBottom){
          //sth
          $(".nicescroll-box").getNiceScroll(0).doScrollTop($('#data-extract'+ind).position().top - $('#data-extract'+ind).height(), 1);
        }else if(elemTop < docViewTop){
          //do scroll
          $(".nicescroll-box").getNiceScroll(0).doScrollTop($('#data-extract'+ind).position().top , 1);
        }
        //draw line
        self.current_key_ind = ind;
        self.updateLine()
      }
    },

    confirmDocument(afterConfirm){
      Object.keys(this.hiddenRect).map((ele,ind) =>{
        delete this.data[this.current]['result']['extracted'][ele]
      })
      console.log(this.data[this.current]['result'])
      let datasend = {}
      datasend['fileId'] = this.data[this.current]['id']
      datasend['result'] = this.data[this.current]['result']
      $('body').addClass("loading");
      $.ajax({
        url: "/review/confirm",
        type: "POST",
        data: JSON.stringify(datasend),
        dataType: 'json',
        contentType: 'application/json',
        // mimeTypes: "multipart/form-data",
        // contentType: false,
        processData: false,
        success: function (res) {
          console.log(res)
          $('body').removeClass("loading");
          if(res.message=="success"){
            console.log("success")
            afterConfirm()
          }
        }, error: function (err) {
          $('body').removeClass("loading");
          alert('request error')
          console.log(err)
        }
      });
    },
    afterConfirm(){
      if(this.data[this.current].status == 1 ){
        this.number_confirmed++;
        this.data[this.current].status = 5
      }
      this.is_cv2_drawed = false
      this.updateLine();
      this.$forceUpdate();
      // alert('sucess')
      // this.showAlert('sucess' )
      let msg =  (langChoose =='ja' ? 'ドキュメント＃': 'The document “')+this.data[this.current].name+(langChoose =='ja' ? 'は': '” completed Confirmed');
      showAlertCustom(msg,2)
      //show alert sucess
    },
    showAlert(msg){
      this.showNotice = true;
      setTimeout(()=>{ this.hideNotice();}, 3000);
    },
    hideNotice(){
      this.showNotice = false;
    },
    reRunOCR(id){
      let datas = {};
      if(this.data[id].status == 2){
        datas[this.data[id].id] = this.data[id].type;
      }
      this.socket.emit('process', {data: datas});
      $("#custom-line").css({"width": "0px"});
    },
    updateLine(){
      if(this.current_key_ind == null){
        this.showLine=false;
        console.log("herre1");
        return;
      }
      let rectCanvas = this.rect.canvas.getActiveObject();
      if(rectCanvas == null){
        this.showLine=false;
        console.log("herre2");
        return;
      }
      let y = $('#data-extract'+this.current_key_ind).offset().top +  $('#data-extract'+this.current_key_ind).height()/2
      let x = $('#data-extract'+this.current_key_ind).offset().left - $("#review").offset().left 
      if( y > $("#bottom-scroll").offset().top || y < ($("#top-scroll").offset().top + $("#top-scroll").height())){
        this.showLine=false;
        console.log("herre3");
        return;
      }

      let pos = rectCanvas.oCoords;
      if(pos.mr.x <0 || pos.mr.y  <0 ){
        this.showLine=false;
        return;
      }
      if(pos.mr.x > this.rect.canvas.width || pos.mr.y > this.rect.canvas.height ){
        this.showLine=false;
        return;
      }
      let startY = $("#canvas").offset().top + pos.mr.y 
      let startX = $("#canvas").offset().left + pos.mr.x - $("#review").offset().left ;
      // let startY = $("#canvas").offset().top + rectCanvas.top + rectCanvas.height/2
      // let startX = $("#canvas").offset().left + rectCanvas.left +rectCanvas.width - $("#review").offset().left;

      // $("#line-connect").attr({x1: startX, y1: startY, x2: x, y2: y})
      $("#line-connect-1").attr({x1: startX, y1: startY, x2: (x+startX)/2, y2: y})
      $("#line-connect-2").attr({x1: (x+startX)/2, y1: y, x2: x-12, y2: y})
      $("#line-connect-3").attr({cx: x, cy: y})
      this.showLine=true;
    },
    updateLine2(transform){
      if(this.current_key_ind == null){
        this.showLine=false;
        console.log("herre1");
        return;
      }
      let rectCanvas = this.rect.canvas.getActiveObject();
      if(rectCanvas == null){
        this.showLine=false;
        console.log("herre2");
        return;
      }
      let y = $('#data-extract'+this.current_key_ind).offset().top +  $('#data-extract'+this.current_key_ind).height()/2
      let x = $('#data-extract'+this.current_key_ind).offset().left - $("#review").offset().left 
      if( y > $("#bottom-scroll").offset().top || y < ($("#top-scroll").offset().top + $("#top-scroll").height())){
        this.showLine=false;
        console.log("herre3");
        return;
      }

      // let mid_right = transform.oCoords.mr;
      // let startY = $("#canvas").offset().top + mid_right.y
      // let startX = $("#canvas").offset().left + mid_right.x - $("#review").offset().left ;
      let startY = $("#canvas").offset().top + transform.top + transform.height*transform.scaleY/2
      let startX = $("#canvas").offset().left + transform.left + transform.width*transform.scaleX - $("#review").offset().left ;

      $("#line-connect-1").attr({x1: startX, y1: startY, x2: (x+startX)/2, y2: y})
      $("#line-connect-2").attr({x1: (x+startX)/2, y1: y, x2: x-12, y2: y})
      $("#line-connect-3").attr({cx: x, cy: y})
      this.showLine=true;
    },
    selectFile() {
      $('#files').click();
    },
    handleFileUpload() {
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
            'type': localData.data.type,
            'name': this.files[i].name,
            'edit': false
          };
          this.additional_data.push(data);
        }
      }

      var formData = new FormData();

      formData.append("packageName", this.fileID)
      for (let i in this.additional_data) {
        formData.append("img_data[]", this.additional_data[i].file);
        formData.append("type_img_" + i, this.additional_data[i].type != null ? this.additional_data[i].type : '');
        formData.append("name_" + i, this.additional_data[i].name);
      }

      $('body').addClass("loading");
      $.ajax({
        url: "/listPackage/" + this.fileID,
        type: "POST",
        data: formData,
        mimeTypes: "multipart/form-data",
        contentType: false,
        processData: false,
        success: function (res) {
          $('body').removeClass("loading");
          window.location.reload()
        }, error: function () {
          $('body').removeClass("loading");
          alert('トライアル範囲を超えました。担当者にご連絡お願い致します。')
        }
      });
      $("#create-folder").modal('toggle');

    },
  }
  
});