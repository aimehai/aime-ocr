function split_data(resp, num_col, num_row) {
  let data = resp['result'];
  let width = resp['size_w'];
  let height = resp['size_h'];
  let d1 = [];
  let d2 = [];

  function check_include(d, x) {
    for (let y of d) {
      if (y['id'] == x['id']) {
        return true
      }
    }
    return false
  }

  function calCenX(x) {
    return (x['x'] + x['w']) / 2;
  }

  function calCenY(x) {
    return (x['y'] + x['h']) / 2;
  }

  function find_col(x) {
    let cen = (x['x'] + x['w']) / 2;
    let d = [];
    for (let m of data) {
      if (Math.abs(cen - calCenX(m)) < width / 20) {
        d.push(m);
        d2.push(m);
      }
    }
    d1.push(d);
  }

  function merge_box(x1, x2) {
    let x = x1;
    x['y'] = x1['y'] < x2['y'] ? x1['y'] : x2['y'];
    x['h'] = x1['y'] + x1['h'] < x2['y'] + x2['h'] ? x2['y'] + x2['h'] - x1['y'] : x1['y'] + x1['h'] - x2['y'];
    x['x'] = x1['x'] < x2['x'] ? x1['x'] : x2['x'];
    x['w'] = x1['x'] + x1['w'] <= x2['x'] + x2['w'] ? x2['x'] + x2['w'] - x1['x'] : x1['x'] + x1['w'] - x2['x'];
    x['text'] = x1['text'] + x2['text'];
    return x
  }

  function merge_row(rows) {
    while (rows.length > num_row) {
      let min = height;
      let id1 = 0;
      let id2 = 0;
      for (let i = 0; i < rows.length - 1; i++) {
        for (let j = i + 1; j < rows.length; j++) {
          let a = Math.abs(calCenY(rows[i]) - calCenY(rows[j]));
          if (a < min) {
            min = a;
            id1 = i;
            id2 = j;
          }
        }
      }
      rows[id1] = merge_box(rows[id1], rows[id2]);
      rows.splice(id2, 1);
    }
  }

  function merge_col() {
    while (d1.length > num_col) {
      for (let i = num_col; i < d1.length; i++) {
        for (let j in d1[i]) {
          let min = width;
          let id = 0;
          let cen = (d1[i][j]['x'] + d1[i][j]['w']) / 2;
          for (let k = 0; k < num_col; k++) {
            for (let l = 0; l < d1[k].length; l++) {
              if (Math.abs(cen - calCenX(d1[k][l])) < min) {
                min = Math.abs(cen - calCenX(d1[k][l]));
                id = d1[k][l]['id'];
              }
            }
          }
          for (let k = 0; k < num_col; k++) {
            for (let l = 0; l < d1[k].length; l++) {
              if (d1[k][l]['id'] == id) {
                d1[k].push(d1[i][j])
              }
            }
          }
        }
        d1.splice(i, 1);
      }
    }
  }

  if (num_row == 1 && num_col == 1) {
    let text = "";
    for (let x of data) {
      text += x['text']
    }
    let arr = merge_box(data[0], data[data.length - 1]);
    arr['text'] = text;
    d1.push([arr]);
  } else {
    for (let x of data) {
      if (!check_include(d2, x)) {
        find_col(x);
      }
    }
    if (d1.length > num_col) {
      merge_col()
    }
    for (let i = 0; i < d1.length; i++) {
      if (d1[i].length > num_row) {
        merge_row(d1[i]);
      }
    }
  }
  return d1
}
function showAlertCustom(msg,type){
  let isJapan = langChoose =='ja'
  switch (type) {
    case 3:
      $.notify({
        icon: "",
          title:"<i class='material-icons'>block</i><b>"+(isJapan? "エラー: ":"ERROR: ")+ "</b> "+msg, 
          message:"",
  
      },{
        type: 'danger',
        timer: 3000,
        placement: {
            from: 'top',
            align: 'center'
        }
      });
    break;
    case 2: 
      $.notify({
        icon: "",
          title:"<i class='material-icons'>done</i><b>"+(isJapan? "完了: ":"SUCCESS: ")+ "</b> "+msg, 
          message:"",
  
      },{
        type: 'sucess',
        timer: 3000,
        placement: {
            from: 'top',
            align: 'center'
        }
      });
    break;
    case 1: 
      $.notify({
        icon: "",
          title:"<i class='material-icons'>warning_amber</i><b>"+(isJapan? "警告: ":"WARNING: ")+ "</b> "+msg, 
          message:"",
  
      },{
        type: 'warning',
        timer: 3000,
        placement: {
            from: 'top',
            align: 'center'
        }
      });
    break;
    case 0: 
    $.notify({
      icon: "",
        title:"<i class='material-icons'>info</i><b>"+(isJapan? "インフォ: ":"INFOR: ")+ "</b> "+msg, 
        message:"",

    },{
      type: 'info',
      timer: 3000,
      placement: {
          from: 'top',
          align: 'center'
      }
    });
  break;
    default:
      break;
  }
}
function updateBreadScrum(arr){
  $("#bread-scrum-ol").empty();
  arr.forEach((element,ind) => {
    if(ind == (arr.length-1)){
      let li_html ='<li class="breadcrumb-item active " aria-current="page">'+ element['name'] +'</li>'
      $("#bread-scrum-ol").append(li_html);
    }else{
      let li_html ='<li class="breadcrumb-item "><a href="'+ element['link'] +'">'+ element['name'] +'</a></li>'
      $("#bread-scrum-ol").append(li_html);
    }
  })
}