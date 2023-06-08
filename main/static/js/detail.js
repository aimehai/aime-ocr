myObject = new Vue({
  el: '#detail',
  data: {
    data: [],
    current: 0,
    data_reduce: [],
    zoomLevel: 1
  },
  beforeMount: function () {
    this.data = localData;
  },
  watch: {
    current: function () {
      this.updateStatus();
      this.drawSvg();
    }
  },
  mounted() {
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
    $(".owl-carousel").owlCarousel({
      startPosition: id != null ? id : 0
    });
    $(".am-next").click(function () {
      $(".owl-carousel").trigger('next.owl.carousel');
    });
    $(".am-prev").click(function () {
      $(".owl-carousel").trigger('prev.owl.carousel');
    });
    this.drawSvg();
  },
  methods: {
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
    showKeyVal: function () {
      console.log(typeof this.data[this.current]['result']['extracted']);
      if (this.data[this.current]['result']['extracted'] != null) {
        $('#show-table').modal('toggle');
      }
    },
    exportExtract() {
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
      fd.append("data", JSON.stringify(this.data[this.current]['result']));
      fd.append("id", this.data[this.current]['id']);
      xhr.open("POST", "/exportv3", true);
      xhr.send(fd);
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
    deleteResult() {
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        if (this.status == 200) {
          window.location.replace('/detail');
        }
      };
      $('body').addClass('loading');
      var fd = new FormData();
      fd.append("data", [this.data[this.current]['id']]);
      xhr.open("POST", "/delete_result", true);
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
          let font_size = t.direction == "vert" ? parseInt(t.w * scale / 1.5) : parseInt(t.h * scale / 1.5);
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
        let h = $('#draw-content').height();
        let per_w = w / data.size_w;
        let per_h = h / data.size_h;
        let per = 0;
        per_w > per_h ? per = per_h : per = per_w;
        per = per > 1 ? 1 : per;
        let html = '<svg  style="background-color: #ffffff" width="' + (parseInt(data.size_w * per)) + '" height="' + (parseInt(data.size_h * per)) + '">' +
            text(data, per);
        '</svg>'
        $('#draw-content').append(html);
      }
    }
  }
});