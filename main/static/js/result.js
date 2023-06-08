resultComponent = new Vue({
  el: '#result',
  data: {
    data: [],
    current: 0,
    data_reduce: [],
    rect: {},
    zoomLevel: 1,
    extractData: {},
    showData: 0
  },
  beforeMount: function () {
    this.data = localData;
    var url = window.location.href;
    url = new URL(url);
    var c = url.searchParams.get("id");
    let id = null;
    if (c && c != null) {
      id = this.data.findIndex(function (a) {
        return a['id'] == c;
      });
    }
    if (id != null) {
      this.current = id;
    }
  },
  mounted() {
    console.log(localData)
    var self = this;
    $(".owl-carousel").owlCarousel({
      startPosition: self.current != null ? self.current : 0
    });
    $(".am-next").click(function () {
      $(".owl-carousel").trigger('next.owl.carousel');
    });
    $(".am-prev").click(function () {
      $(".owl-carousel").trigger('prev.owl.carousel');
    });
    var wi = 650;
    var h = 100;
    if (window.screen.width < 1250) {
      wi = 550;
      h = 50;
    }
    var canvas = new fabric.Canvas('canvas', {
      width: wi, height: wi
    });
    var cropped = document.getElementById('canvas2');
    $(cropped).width(wi);
    $(cropped).height(h);
    if (self.data[self.current]['raw_path'] != null && self.data[self.current]['raw_path'] != '') {
      self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,true);
    } else {
      self.rect = new Rectangle(canvas, 'static/uploaded/' + self.data[self.current]['raw_path'], cropped,true);
    }
    $('.canvas-container').on('mousewheel', function (options) {
      var delta = options.originalEvent.wheelDelta;
      if (delta != 0) {
        options.preventDefault();
        var pointer = canvas.getPointer(options, true);
        var point = new fabric.Point(pointer.x, pointer.y);
        if (delta > 0) {
          self.rect.zoomIn(point);
        } else if (delta < 0) {
          self.rect.zoomOut(point);
        }
      }
    });

    this.rect.drawSuccess = function () {
      if (self.data[self.current]['result'] != null) {
        self.data[self.current]['result'] = JSON.parse(self.data[self.current]['result'])
      }
      if (self.data[self.current]['format'] && self.data[self.current]['format'] != null) {
        let list = JSON.parse(self.data[self.current]['format']);
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
        x.selectable = false;
        x.selection = false;
      }
    };

    this.rect.callBack = function () {
      let rec = self.rect.canvas.getActiveObject();
      let key = rec['key'];
      let rows = $('tr');
      rows.removeClass('active');
      $("tr[data-value=" + key + "]").addClass('active');
      $("tr[data-value=" + key + "]")[0].scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    }
  },
  methods: {
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
          let list = JSON.parse(self.data[self.current]['format']);
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
    selectRect(key, e) {
      let x = null;
      for (let a of this.rect.labels) {
        if (a['key'] == key) {
          x = a;
          break;
        }
      }
      this.rect.selectObj(x);
      $('tr').removeClass('active');
      $(e.target).parent('tr').addClass('active');
      this.rect.canvas.setActiveObject(null);

    },
    showKeyVal: function () {
      if (this.data[this.current]['result']['extracted'] != null) {
        $('#show-table').modal('toggle');
      }
    },
    removeLabel(key, e) {
      let f = this.rect.labels.find(rec => rec['key'] == key);
      this.rect.removeLabel(f);
      $(e.target).parents('tr')[0].remove()
      delete this.data[this.current]['result']['extracted'][key];
    },
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
    showStatus(type) {
      if (type == 0) {
        return '実行中'
      } else if (type == 1) {
        return '実行済み'
      } else if (type == 2) {
        return 'エラー'
      } else if (type == 3) {
        return '未実行'
      }
    },
    updateExport() {
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
    nextImg() {
      if (this.current < this.data.length - 1) {
        this.current += 1;
      }
    },
    prevImg() {
      if (this.current > 0) {
        this.current -= 1;
      }
    },
    selectImg(id) {
      this.current = id;
      window.location.replace('/result?id=' + this.data[this.current].id);
    },
    redirect(url) {
      window.location.replace(url)
    },
    showImg(src) {
      $('#imagemodal').modal('show');
      var self = this;
      var zX = self.zoomLevel;
      $('.imagepreview').attr('src', src);
      $('#imagemodal .modal-dialog').bind('mousewheel', function (e) {
        var dir = 0;
        if (e.originalEvent.wheelDelta > 0) {
          dir += 0.1;
        } else {
          dir -= 0.1;
        }
        self.zoomLevel += dir;
        if (self.zoomLevel < 4 && self.zoomLevel >= 1) {
          $(this).css('transform', 'scale(' + self.zoomLevel + ')');
        } else if (self.zoomLevel >= 4) {
          self.zoomLevel = 4;
        } else {
          self.zoomLevel = 1;
        }
      });
    },
    showSVG() {
      $('#show-svg .modal-body').empty();
      let txt = $('#draw-content').html();
      let wd = $('#draw-content').width();

      $('#show-svg .modal-body').append(txt);
      $('#show-svg').modal('show');
      var self = this;
      $('#show-svg .modal-content').width(wd + 50);
      $('#show-svg').bind('mousewheel', function (e) {
        var dir = 0;
        if (e.originalEvent.wheelDelta > 0) {
          dir += 0.1;
        } else {
          dir -= 0.1;
        }
        self.zoomLevel += dir;
        if (self.zoomLevel < 4.0 && self.zoomLevel >= 1) {
          $(this).css('transform', 'scale(' + self.zoomLevel + ')');
        } else if (self.zoomLevel >= 4.0) {
          self.zoomLevel = 4.0;
        } else {
          self.zoomLevel = 1;
        }
      });
    },
    drawSvg() {
      function text(data, scale) {
        let html = "";
        let pad = 0;
        for (let i in data.result) {
          let t = data.result[i];
          let font_size = t.direction == "vert" ? parseInt(t.w * scale / 1.3) : parseInt(t.h * scale / 1.3);
          if (parseInt(t.y) < parseInt(t.h) && t.direction == "horiz")
            pad = parseInt(t.h - t.y);
          html += '<text x="' + parseInt(parseInt(t.x) * scale) + '" y="' + parseInt(parseInt(t.y + pad) * scale) + '" width="' + parseInt(parseInt(t.w) * scale) + '" height="' + parseInt(parseInt(t.h) * scale) + '" font-size="' + (font_size) + '"' + (t.direction == "vert" ? 'transform="rotate(90 ' + parseInt(parseInt(t.x) * scale) + ', ' + parseInt(parseInt(t.y + pad) * scale) + ')"' : '') + '">' + t.text + '</text>'
        }
        return html;
      }

      $('#draw-content').html('');
      if (this.data[this.current]['result'] != null) {
        let data = this.data[this.current]['result']['raw'];
        let w = $('#draw-content').width();
        let per = w / data.size_w;
        per = per > 1 ? 1 : per;
        let html = '<svg  style="background-color: #ffffff" width="' + w + '" height="' + (parseInt(data.size_h * per)) + '">' +
            text(data, per);
        '</svg>'
        $('#draw-content').append(html);
      }
    }
  }
});