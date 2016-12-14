//var task_jsonrpc = imprt("jsonrpc");
//var task_service = new task_jsonrpc.ServiceProxy("taskupload_js.yaws", ["upload"]);

$(function()
  {
    $("#upload").click(
      function()
      {
        var selButton = document.getElementsByName("task_type");
        if (selButton[0].checked == true) {
          var timer = $("#loop_timer").val();
          if (timer < 0) {
          alert("定时时间不能小于0");
          return false;
          }
        } else if (selButton[1].checked == true) {
          var min = $("#date_min option:selected").val();
          var hour = $("#date_hour option:selected").val();
          var day = $("#date_day option:selected").val();
          var month = $("#date_month option:selected").val();
          var week = $("#date_week option:selected").val();
          if (min == "*" && hour == "*" && day == "*" && month == "*" && week == "*") {
            alert("请设置时间");
            return false;
          }
          else if ((hour != "*") && (min == "*")) {
            alert("请设置分钟");
            return false;
          }
          else if ((month != "*" || day != "*" || week != "*") && (min == "*")) {
            alert("请设置具体时间--分钟 or 分钟/小时");
            return false;
          }
          else if ((day != "*") && (week != "*") ) {
            alert("(星期)或者(日)只能设置一项");
            return false;
          }

        }
        else {
          alert("请选择任务类型!");
          return false;
        }
        
        var task_path = $("#file").val();

        if (task_path == "") {
          alert("请添加任务文件");
          return false;
        }

        $("#form1").submit();
//	      task_service.upload(timer, task_path);
      }
    );

    $("#get_task_all").click(
      function()
      {
        $.getJSON("getalltask.yaws",
                 {'op':"getalltask", 'value':"hello"},
                 function(x){
                   handle_taskinfo(x);
                 }
          );
        return false;
      }
    );

    function handle_taskinfo(x) {
      $("#form3").empty();
      
      jQuery.each(x, function(i, value) {
        var ItemValue="";
        jQuery.each(value, function(j, value) {
          if (j == "name" || j == "timeout" || j == "cmd") {
            ItemValue = ItemValue + j + ":" + value + "|";
          }
        });
        //if (i == 0){
        //  $("#form3").append("<input type='checkbox' name='selAllTaskCheckBox' id=selAllTaskCheckBox value='全选' onclick='checkSelAll(this)'>"
        //                   + "<label for='selAllTaskCheckBox'>全选</label>" + "<br/>");
        //}
        $("#form3").append("<input type='checkbox' name='taskListCheckBox' id=taskListCheckBox" + i + " value='" + ItemValue + "' >"
                           + "<label for='taskListCheckBox" + i + "'>" + ItemValue + "</label>" + "<br/>");
      });
    }

    $("#delete_task").click(
      function()
      {
        var selCheckBox = document.getElementsByName("taskListCheckBox");
        var taskNameList = [];
        var taskNameIndex = 0;
        for (var i = 0; i < selCheckBox.length; i++) {
          if (selCheckBox[i].checked == true) {
            taskNameList[taskNameIndex] = selCheckBox[i].value.substring(selCheckBox[i].value.indexOf("name:") + 5,
                                                                         selCheckBox[i].value.indexOf("|"));
            taskNameIndex++;
          }
        }

        if (taskNameList.length == 0) {
          alert("至少选择一个需要删除的任务！");
          return false;
        }

        $.getJSON("getalltask.yaws",
                 {'op':"deletetask", 'value': taskNameList},
                 function(x){
                   handle_taskinfo(x);
                 }
          );
        return false;
      }
    );

    $("#selAllTaskCheckBox").change(
      function () {
        var selCheckBox = document.getElementsByName("taskListCheckBox");
        if ($("#selAllTaskCheckBox").prop("checked"))
        {
          for (var i = 0; i < selCheckBox.length; i++) {
            selCheckBox[i].checked = true;
          }         
        }
        else {
          for (var i = 0; i < selCheckBox.length; i++) {
              selCheckBox[i].checked = false;
          }      
        }

      }
    );


  }
);