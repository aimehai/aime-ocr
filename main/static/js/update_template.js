myObject = new Vue({
  el: '#update_template',
  data: {
    list: [],
    formats: [],
    default_type: null,
    file: null,
    editedTodo: null,
    rect: null,
    listColumn: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'AA', 'AB', 'AC', 'AD', 'AE', 'AF', 'AG', 'AH', 'AI', 'AJ', 'AK', 'AL', 'AM', 'AN', 'AO', 'AP', 'AQ', 'AR', 'AS', 'AT', 'AU', 'AV', 'AW', 'AX', 'AY', 'AZ', 'BA', 'BB', 'BC', 'BD', 'BE', 'BF', 'BG', 'BH', 'BI', 'BJ', 'BK', 'BL', 'BM', 'BN', 'BO', 'BP', 'BQ', 'BR', 'BS', 'BT', 'BU', 'BV', 'BW', 'BX', 'BY', 'BZ', 'CA', 'CB', 'CC', 'CD', 'CE', 'CF', 'CG', 'CH', 'CI', 'CJ', 'CK', 'CL', 'CM', 'CN', 'CO', 'CP', 'CQ', 'CR', 'CS', 'CT', 'CU', 'CV', 'CW', 'CX', 'CY', 'CZ', 'DA', 'DB', 'DC', 'DD', 'DE', 'DF', 'DG', 'DH', 'DI', 'DJ', 'DK', 'DL', 'DM', 'DN', 'DO', 'DP', 'DQ', 'DR', 'DS', 'DT', 'DU', 'DV', 'DW', 'DX', 'DY', 'DZ', 'EA', 'EB', 'EC', 'ED', 'EE', 'EF', 'EG', 'EH', 'EI', 'EK', 'EL', 'EM', 'EN', 'EO', 'EP', 'EQ', 'ER', 'ES', 'ET', 'EV', 'EX', 'EY', 'EZ', 'FA', 'FB', 'FC', 'FD', 'FE', 'FF', 'FG', 'FH', 'FI', 'FK', 'FL', 'FM', 'FN', 'FO', 'FP', 'FQ', 'FR', 'FS', 'FT', 'FV', 'FX', 'FY', 'FZ', 'GA', 'GB', 'GC', 'GD', 'GE', 'GF', 'GG', 'GH', 'GI', 'GK', 'GL', 'GM', 'GN', 'GO', 'GP', 'GQ', 'GR', 'GS', 'GT', 'GV', 'GX', 'GY', 'GZ', 'HA', 'HB', 'HC', 'HD', 'HE', 'HF', 'HG', 'HH', 'HI', 'HK', 'HL', 'HM', 'HN', 'HO', 'HP', 'HQ', 'HR', 'HS', 'HT', 'HV', 'HX', 'HY', 'HZ', 'IA', 'IB', 'IC', 'ID', 'IE', 'IF', 'IG', 'IH', 'II', 'IK', 'IL', 'IM', 'IN', 'IO', 'IP', 'IQ', 'IR', 'IS', 'IT', 'IV', 'IX', 'IY', 'IZ', 'KA', 'KB', 'KC', 'KD', 'KE', 'KF', 'KG', 'KH', 'KI', 'KK', 'KL', 'KM', 'KN', 'KO', 'KP', 'KQ', 'KR', 'KS', 'KT', 'KV', 'KX', 'KY', 'KZ', 'LA', 'LB', 'LC', 'LD', 'LE', 'LF', 'LG', 'LH', 'LI', 'LK', 'LL', 'LM', 'LN', 'LO', 'LP', 'LQ', 'LR', 'LS', 'LT', 'LV', 'LX', 'LY', 'LZ', 'MA', 'MB', 'MC', 'MD', 'ME', 'MF', 'MG', 'MH', 'MI', 'MK', 'ML', 'MM', 'MN', 'MO', 'MP', 'MQ', 'MR', 'MS', 'MT', 'MV', 'MX', 'MY', 'MZ', 'NA', 'NB', 'NC', 'ND', 'NE', 'NF', 'NG', 'NH', 'NI', 'NK', 'NL', 'NM', 'NN', 'NO', 'NP', 'NQ', 'NR', 'NS', 'NT', 'NV', 'NX', 'NY', 'NZ', 'OA', 'OB', 'OC', 'OD', 'OE', 'OF', 'OG', 'OH', 'OI', 'OK', 'OL', 'OM', 'ON', 'OO', 'OP', 'OQ', 'OR', 'OS', 'OT', 'OV', 'OX', 'OY', 'OZ', 'PA', 'PB', 'PC', 'PD', 'PE', 'PF', 'PG', 'PH', 'PI', 'PK', 'PL', 'PM', 'PN', 'PO', 'PP', 'PQ', 'PR', 'PS', 'PT', 'PV', 'PX', 'PY', 'PZ', 'QA', 'QB', 'QC', 'QD', 'QE', 'QF', 'QG', 'QH', 'QI', 'QK', 'QL', 'QM', 'QN', 'QO', 'QP', 'QQ', 'QR', 'QS', 'QT', 'QV', 'QX', 'QY', 'QZ', 'RA', 'RB', 'RC', 'RD', 'RE', 'RF', 'RG', 'RH', 'RI', 'RK', 'RL', 'RM', 'RN', 'RO', 'RP', 'RQ', 'RR', 'RS', 'RT', 'RV', 'RX', 'RY', 'RZ', 'SA', 'SB', 'SC', 'SD', 'SE', 'SF', 'SG', 'SH', 'SI', 'SK', 'SL', 'SM', 'SN', 'SO', 'SP', 'SQ', 'SR', 'SS', 'ST', 'SV', 'SX', 'SY', 'SZ', 'TA', 'TB', 'TC', 'TD', 'TE', 'TF', 'TG', 'TH', 'TI', 'TK', 'TL', 'TM', 'TN', 'TO', 'TP', 'TQ', 'TR', 'TS', 'TT', 'TV', 'TX', 'TY', 'TZ', 'VA', 'VB', 'VC', 'VD', 'VE', 'VF', 'VG', 'VH', 'VI', 'VK', 'VL', 'VM', 'VN', 'VO', 'VP', 'VQ', 'VR', 'VS', 'VT', 'VV', 'VX', 'VY', 'VZ', 'XA', 'XB', 'XC', 'XD', 'XE', 'XF', 'XG', 'XH', 'XI', 'XK', 'XL', 'XM', 'XN', 'XO', 'XP', 'XQ', 'XR', 'XS', 'XT', 'XV', 'XX', 'XY', 'XZ', 'YA', 'YB', 'YC', 'YD', 'YE', 'YF', 'YG', 'YH', 'YI', 'YK', 'YL', 'YM', 'YN', 'YO', 'YP', 'YQ', 'YR', 'YS', 'YT', 'YV', 'YX', 'YY', 'YZ', 'ZA', 'ZB', 'ZC', 'ZD', 'ZE', 'ZF', 'ZG', 'ZH', 'ZI', 'ZK', 'ZL', 'ZM', 'ZN', 'ZO', 'ZP', 'ZQ', 'ZR', 'ZS', 'ZT', 'ZV', 'ZX', 'ZY', 'ZZ'],
    nextColumn: 0,
    columnSelected: [],
    selectedBox: null,
    extracted: null,
    extractedRow: null,
    extractedCol: null,
    id: null
  },
  beforeMount: function () {
    this.formats = localData;
    let path = window.location.pathname.split('/');
    this.id = path[path.length - 1]
  },
  mounted() {
    if (this.formats['img_path'] != null) {
      this.file = this.formats['img_path'];
      this.showContent2()
    }
  },
  created() {
    window.onbeforeunload = function (e) {
      return 'You sure you want to leave?';
    };
  },
  methods: {
    updateList() {
      this.columnSelected = [];
      for (let x of this.rect.labels) {
        this.columnSelected.push(x.position)
      }
      this.columnSelected.sort((a, b) => a.length === b.length ? a < b ? -1 : 1 : a.length - b.length);
      this.nextColumn = this.listColumn.indexOf(this.columnSelected[this.columnSelected.length - 1]) + 1;
      this.rect.callBack(); 
    },
    findNextColumn() {
      return this.listColumn[this.nextColumn]
    },
    selectFile() {
      $('#files').click();
    },
    fileDragHover(e) {
      var fileDrag = document.getElementById('upload-content');
      e.stopPropagation();
      e.preventDefault();
      fileDrag.className = (e.type === 'dragover' ? 'hover' : 'card-body');
    },
    deleteImg(index) {
      this.list.splice(index, 1);
    },
    fileDropHover(e) {
      var fileDrag = document.getElementById('upload-content');
      fileDrag.className = 'card-body';
      let droppedFiles = e.dataTransfer.files;
      if (!droppedFiles) return;
      this.file = droppedFiles[0];
      var self = this;
      if (this.file.type.match('application/pdf')) {
        var url = URL.createObjectURL(this.file);
        PDFJS.getDocument({url: url}).then(function (pdf_doc) {
          pdf_doc.getPage(1).then(function (page) {
            var canv = document.createElement('canvas');
            var viewport = page.getViewport(2);
            canv.width = viewport.width;
            canv.height = viewport.height;
            var ctx = canv.getContext('2d');
            var renderContext = {
              canvasContext: ctx,
              viewport: viewport
            };
            page.render(renderContext).then(function () {
              var b64Image = canv.toDataURL('image/jpeg');
              var u8Image = self.b64ToUint8Array(b64Image);
              self.file = new Blob([u8Image], {type: "image/jpg"});
              self.showContent();
            })
          });
        }).catch(function (error) {
          alert(error.message);
        });
      } else {
        this.showContent();
      }
    },
    editTodo: function (todo) {
      this.list = todo;
    },
    handleFilesUpload() {
      this.file = this.$refs.files.files[0];
      // var self = this;
      // if (this.file.type.match('application/pdf')) {
      //   var url = URL.createObjectURL(this.file);
      //   PDFJS.getDocument({url: url}).then(function (pdf_doc) {
      //     pdf_doc.getPage(1).then(function (page) {
      //       var canv = document.createElement('canvas');
      //       var viewport = page.getViewport(2);
      //       canv.width = viewport.width;
      //       canv.height = viewport.height;
      //       var ctx = canv.getContext('2d');
      //       var renderContext = {
      //         canvasContext: ctx,
      //         viewport: viewport
      //       };
      //       page.render(renderContext).then(function () {
      //         var b64Image = canv.toDataURL('image/jpeg');
      //         var u8Image = self.b64ToUint8Array(b64Image);
      //         self.file = new Blob([u8Image], {type: "image/jpg"});
      //         self.showContent();
      //       })
      //     });
      //   }).catch(function (error) {
      //     alert(error.message);
      //   });
      // } else {
      //   this.showContent();
      // }
      var xhr = new XMLHttpRequest();
      xhr.onload = function () {
        $('body').removeClass('loading');
        window.location.reload()
      };
      $('body').addClass('loading');
      var fd = new FormData();
      if (typeof this.file != "string") {
        fd.append("file", this.file);
      }
      fd.append("data", null);
      fd.append("id", this.id);
      xhr.open("POST", "/save_template", true);
      xhr.send(fd);
    },
    clear() {
      this.list = [];
      this.file = null
    },
    selectRect(x) {
      this.rect.selectObj(x);
      let line = null;
      for (let i in this.rect.labels) {
        if (this.rect.labels[i] === x) {
          line = parseInt(i);
          break
        }
      }
      let elmnt = document.getElementById('form-item-' + line);
      $('.form-head').removeClass('active');
      $(elmnt).find('.form-head').addClass('active');
    },
    showContent2() {
      var wi = 850;
      var h = 100;
      if (window.screen.width < 1450) {
        wi = 600;
        h = 50;
      }
      if (window.screen.width < 1250) {
        wi = 650;
        h = 50;
      }
      var canvas = new fabric.Canvas('canvas', {
        width: wi, height: wi
      });
      this.rect = new Rectangle(canvas, '../static/uploaded/' + this.formats['img_path'],null,true);
      var self = this;
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
      this.rect.boxCreated = function () {
        let rec = self.rect.canvas.getActiveObject();
        if (rec != null) {
          if (rec.position === '') {
            rec.position = self.findNextColumn();
          } else {
            self.columnSelected.push(rec.position)
          }
          if (rec.key == null || rec.key === '') {
            rec.key = rec.position;
          }
        }
        self.updateList()
      };
      this.rect.removeSuccess = function () {
        self.updateList()
      };
      this.rect.callBack = function () {
        let rec = self.rect.canvas.getActiveObject();
        let line = null;
        for (let i in self.rect.labels) {
          if (self.rect.labels[i] === rec) {
            line = parseInt(i);
            break
          }
        }
        let elmnt = document.getElementById('form-item-' + line);
        if (elmnt != null) {
          elmnt.scrollIntoView({
            behavior: 'smooth',
            block: 'center'
          });
          // $('.form-head').css('color', 'black');
          // $(elmnt).find('.form-head').css('color', 'red');

          $('.form-head').removeClass('active');
          $(elmnt).find('.form-head').addClass('active');

        }
      };
      this.rect.drawSuccess = function () {
        if (self.formats['description'] != null) {
          var list = JSON.parse(self.formats['description']);
          for (let x of list['results']) {
            self.rect.addLabel(x["x"], x["y"], x["w"], x["h"], x['model'], null, null, null, x['columns'], x['rows'], x['key'], x['details'], x['position'], x['display']);
          }
        }
        $('.setting-content').height($(window).height() - 200);
      };
    },
    getMeta(url) {
      var img = new Image();
      img.onload = function () {
        alert(this.width + ' ' + this.height);
      };
      img.src = url;
    },
    // showContent() {
    //   var wi = 750;
    //   var h = 100;
    //   if (window.screen.width < 1250) {
    //     wi = 550;
    //     h = 50;
    //   }
    //   var canvas = new fabric.Canvas('canvas', {
    //     width: wi, height: wi
    //   });
    //   let url = URL.createObjectURL(this.file);
    //   this.rect = new Rectangle(canvas, url);
    //   var self = this;
    //   $('.canvas-container').on('mousewheel', function (options) {
    //     var delta = options.originalEvent.wheelDelta;
    //     if (delta != 0) {
    //       options.preventDefault();
    //       var pointer = canvas.getPointer(options, true);
    //       var point = new fabric.Point(pointer.x, pointer.y);
    //       if (delta > 0) {
    //         self.rect.zoomIn(point);
    //       } else if (delta < 0) {
    //         self.rect.zoomOut(point);
    //       }
    //     }
    //   });
    //   this.rect.boxCreated = function () {
    //     let rec = self.rect.canvas.getActiveObject();
    //     if (rec != null) {
    //       if (rec.position === '') {
    //         rec.position = self.findNextColumn();
    //       } else {
    //         self.columnSelected.push(rec.position)
    //       }
    //     }
    //     self.updateList()
    //   };
    //
    //   this.rect.drawSuccess = function () {
    //     $('.setting-content').height(self.rect.scaledSize.height);
    //   };
    //   this.rect.removeSuccess = function () {
    //     self.updateList()
    //   };
    //   this.rect.callBack = function () {
    //     let rec = self.rect.canvas.getActiveObject();
    //     let line = null;
    //     for (let i in self.rect.labels) {
    //       if (self.rect.labels[i] === rec) {
    //         line = parseInt(i);
    //         break
    //       }
    //     }
    //     let elmnt = document.getElementById('form-item-' + line);
    //     if (elmnt != null) {
    //       elmnt.scrollIntoView({
    //         behavior: 'smooth',
    //         block: 'center'
    //       });
    //       $('.form-head').removeClass('active');
    //       $(elmnt).find('.form-head').addClass('active');
    //       // $(elmnt).find('input[type=text]')[0].focus();
    //       // $('.form-item').css("color", "black");
    //       // console.log($(elmnt));
    //     }
    //   }
    // },
    showDetail(box, id) {
      $('#update-detail').modal('toggle');
      var cropped = document.getElementById('show-cropped');
      this.selectedBox = id;
      this.rect.drawCropped(cropped, box);
    },
    update() {
      var xhr = new XMLHttpRequest();
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
      xhr.onload = function () {
        $('body').removeClass('loading');
      };
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
      fd.append("file", this.file);
      fd.append("data", JSON.stringify(data));
      fd.append("id", this.data[this.current]['id']);
      xhr.open("POST", "/export_extracted", true);
      xhr.send(fd);
    },
    reload() {
      window.location.reload();
    },
    b64ToUint8Array(b64Image) {
      var img = atob(b64Image.split(',')[1]);
      var img_buffer = [];
      var i = 0;
      while (i < img.length) {
        img_buffer.push(img.charCodeAt(i));
        i++;
      }
      return new Uint8Array(img_buffer);
    },
    saveTemplate() {
      var xhr = new XMLHttpRequest();
      let data = [];
      let zoom = this.rect.getScaleSized()['scale'];
      for (let lab of this.rect.labels) {
        let d = {
          'x': Math.round(lab.left / zoom),
          'y': Math.round(lab.top / zoom),
          'w': Math.round(lab.width / zoom),
          'h': Math.round(lab.height / zoom),
          'details': lab['details'] ? lab['details'][0] : null,
          'key': lab.key,
          'rows': lab.rows,
          'columns': lab.columns,
          'position': lab.position,
          'model': lab.model,
          'display': lab.display,
        };
        data.push(d);
      }
      xhr.onload = function () {
        $('body').removeClass('loading');
      };
      $('body').addClass('loading');
      var fd = new FormData();
      if (typeof this.file != "string") {
        fd.append("file", this.file);
      }
      fd.append("data", JSON.stringify(data));
      fd.append("id", this.id);
      xhr.open("POST", "/save_template", true);
      xhr.send(fd);
    },
    getText: async function (id) {
      var b64Image = await this.rect.drawCropped2(this.rect.labels[id]);
      var u8Image = this.b64ToUint8Array(b64Image);

      var formData = new FormData();
      formData.append("model", this.rect.labels[id]['model']);
      formData.append("columns", this.rect.labels[id]['columns']);
      formData.append("rows", this.rect.labels[id]['rows']);
      formData.append("file", new Blob([u8Image], {type: "image/jpg"}));

      var xhr = new XMLHttpRequest();
      $('body').addClass('loading');
      xhr.open("POST", "/get_text", true);
      xhr.send(formData);

      var self = this;
      xhr.onload = function () {
        $('body').removeClass('loading');
        self.extracted = JSON.parse(this.response);
        self.extractedRow = parseInt(self.rect.labels[id]['rows']);
        self.extractedCol = parseInt(self.rect.labels[id]['columns']);
        $('#testdata').modal('toggle');
      };
    },
    removeLabel: function (x) {
      this.rect.removeLabel(x);
      this.rect.canvas.renderAll();
    }
  }
})
;