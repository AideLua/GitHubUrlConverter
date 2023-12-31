require "import"
import "android.app.*"
import "android.os.*"
import "android.widget.*"
import "android.view.*"
import "android.text.Html"
import "android.text.util.Linkify"
import "android.webkit.WebView"
import "com.onegravity.rteditor.RTEditorMovementMethod"
import "android.text.util.Linkify"
import "res"
import "themeutil"
import "helper.DialogHelper"
import "util.UrlConverter"
import "init"
import "configs.toolConfigs"
import "configs.converterConfigs"

require "helper"

--import "base64"
--import "markdown.MarkdownHelper"
--import "com.zzhoujay.markdown.MarkDown"

KEY_SELECTED_GITHUB="UrlConverter.selected.github"
KEY_SELECTED_FORMATTER="UrlConverter.selected.%s"

KEY_PLATFORM_SELECTED_FORMAT="UrlConverter.platform.selected.%s"

KEY_DIRECT_CONVERT_MACHINES="UrlConverter.directConvert.machines"

KEY_DIRECT_CONVERT_MACHINE_FORMATTER="UrlConverter.directConvert.machine.%s"

KEY_TERM_USER="term.user"
KEY_TERM_PRIVACY="term.privacy"

VERSION_TERM_USER="v1.2"
VERSION_TERM_PRIVACY="v1.2"

activity.setTheme(android.R.style.Theme)
local enableEMUITheme=false
if not enableEMUITheme then
  themeutil.isEmuiSystem=false
  androidhwext=nil
end
themeutil.applyTheme()

elementMargin=themeutil.isEmuiSystem and "4dp" or nil

activity.setContentView(loadlayout("layout"))
actionBar=activity.getActionBar()

messageView.textIsSelectable=true
messageView.movementMethod=RTEditorMovementMethod.instance

if Build.VERSION.SDK_INT>=25 then
  messageView.revealOnFocusHint=false
  --messageView.requestFocus()
end

activity.getActionBar().setSubtitle(("v%s (%s)"):format(BuildConfig.VERSION_NAME,BuildConfig.VERSION_CODE))

---@type PlatformConfig[]
local platformConfigs=toolConfigs.platforms
---@type table<string,PlatformConfig>
local platformKey2ConfigMap={}
---@type PlatformConfig
local nowPlatform
---@type ConverterConfig|nil
local nowConverterConfigs

local customPlatformConfigsMD5
local customConverterConfigsMD5

local platformsGroupName="github"

local isMenuLoaded=false

function onCreateOptionsMenu(menu)
  menu.add(0,0,0,"gh-proxy 开源仓库")
  local settingsMenu=menu.addSubMenu("设置...")
  settingsMenu.add(0,2,0,"编辑平台配置")
  settingsMenu.add(0,3,0,"编辑转换器配置")
  directConvertMenu=settingsMenu.add(0,5,0,"直接转换")
  .setCheckable(true)
  menu.add(0,4,0,"使用文档")
  menu.add(0,1,0,"关于")
  isMenuLoaded=true
  refreshMenus()
end

function onOptionsItemSelected(item)
  local id=item.getItemId()
  if id==0 then--gh-proxy 开源仓库
    openInBrowser("https://github.com/hunshcn/gh-proxy/")
   elseif id==1 then--关于
    showAboutDialog()
   elseif id==2 then
    openInOtherApp(activity.getUriForFile(FILE_PLATFORM_CONFIGS))
   elseif id==3 then
    openInOtherApp(activity.getUriForFile(FILE_CONVERTER_CONFIGS))
   elseif id==4 then
    openInBrowser("https://gitee.com/Jesse205/GitHubUrlConverter/blob/master/docs/README.md")
   elseif id==5 then
    switchDirectConvert()
  end
end

function switchDirectConvert()
  if nowConverterConfigs then
    if directConvertMenu.isChecked() then
      directConvertMenu.setChecked(false)
      activity.setSharedData(KEY_DIRECT_CONVERT_MACHINE_FORMATTER:format(nowPlatform.key),nil)
     else
      local dialog=AlertDialog.Builder(this)
      .setTitle("直接转换")
      .setMessage("勾选该平台的该转换器后，当您在外部分享链接到本 APP 内时，本 APP 会自动使用本转换器转换并使用浏览器打开此链接。")
      .setPositiveButton(android.R.string.ok,function()
        directConvertMenu.setChecked(true)
        activity.setSharedData(KEY_DIRECT_CONVERT_MACHINE_FORMATTER:format(nowPlatform.key),nowConverterConfigs.key)
      end)
      .setNegativeButton(android.R.string.no,nil)
      .show()
    end
  end
end

function onNewIntent(newIntent)
  parseIntent(newIntent,true)
end

function refreshMenus()
  if not isMenuLoaded then
    return
  end
  directConvertMenu.setEnabled(not not(nowConverterConfigs))
  directConvertMenu.setChecked(not not(nowConverterConfigs and activity.getSharedData(KEY_DIRECT_CONVERT_MACHINE_FORMATTER:format(nowPlatform.key))==nowConverterConfigs.key))
end

---显示关于对话框
function showAboutDialog()
  local dialog=AlertDialog.Builder(this)
  .setTitle(R.string.app_name)
  .setIcon(R.mipmap.ic_launcher)
  .setMessage("")
  .setPositiveButton(android.R.string.ok,nil)
  .setNeutralButton("法律信息...",nil)
  .setNegativeButton("开源仓库",nil)
  .show()
  local termUrlList={"https://gitee.com/Jesse205/GitHubUrlConverter/blob/master/docs/terms/user_v1.2.md",
    "https://gitee.com/Jesse205/GitHubUrlConverter/blob/master/docs/terms/privacy_v1.2.md",
    "https://gitee.com/Jesse205/GitHubUrlConverter/blob/master/docs/terms/license_v1.2.md",
    "https://gitee.com/Jesse205/GitHubUrlConverter/blob/master/docs/terms/sharing_v1.2.md"}

  local messageView=dialog.findViewById(android.R.id.message)
  local neutralButton=dialog.getButton(Dialog.BUTTON_NEUTRAL)
  local negativeButton=dialog.getButton(Dialog.BUTTON_NEGATIVE)
  messageView.setAutoLinkMask(Linkify.WEB_URLS|Linkify.EMAIL_ADDRESSES)
  messageView.setTextIsSelectable(true)
  messageView.setMovementMethod(RTEditorMovementMethod.getInstance())
  messageView.setText([[
软件版本: v]]..BuildConfig.VERSION_NAME..(" (%s)"):format(BuildConfig.VERSION_CODE)..[[ 
UrlConverter 版本：v]]..UrlConverter._VERSION..(" (%s)"):format(UrlConverter._VERSION_CODE)..[[ 
开源许可: MIT
软件&源码: https://www.123pan.com/s/G7a9-4xtk
反馈邮箱: jesse205@qq.com

]]..description)
  --设置为文本后需要取消自动连接，否则会点击重复
  messageView.setAutoLinkMask(0)

  messageView.requestFocus()
  local termPopupMenu=PopupMenu(activity,neutralButton)
  local menu=termPopupMenu.getMenu()
  menu.add(0,1,0,"用户协议")
  menu.add(0,2,0,"隐私政策")
  menu.add(0,3,0,"开源许可")
  menu.add(0,4,0,"第三方信息共享")
  termPopupMenu.setOnMenuItemClickListener({
    onMenuItemClick=function(item)
      local itemId=item.getItemId()
      if itemId>=1 and itemId<=4 and termUrlList[itemId] then
        openInBrowser(termUrlList[itemId])
      end
    end
  })
  neutralButton.onClick=function(view)
    termPopupMenu.show()
  end
  neutralButton.setOnTouchListener(termPopupMenu.getDragToOpenListener())
  negativeButton.onClick=function(view)
    openInBrowser("https://gitee.com/Jesse205/GitHubUrlConverter")
  end
end

--检测是否需要重新加载
function needRecreate()
  local customPlatformConfigsJson,errMsg=readFile(PATH_PLATFORM_CONFIGS)
  if not errMsg then
    local contentMD5=LuaUtil.getMD5(customPlatformConfigsJson)
    if contentMD5~=customPlatformConfigsMD5 then
      return true
    end
  end
  local customConverterConfigsJson,errMsg=readFile(PATH_CONVERTER_CONFIGS)
  if not errMsg then
    local contentMD5=LuaUtil.getMD5(customConverterConfigsJson)
    if contentMD5~=customConverterConfigsMD5 then
      return true
    end
  end
  return false
end

---获取转换后的链接
---@return url string 已转换的链接
function getConvertedUrl()
  assert(nowConverterConfigs,"转换器配置为空")
  return convertUrl(inputEdit.text,nowConverterConfigs)
end

---解析 Intent
---@param intent Intent 要解析的 Intent
function parseIntent(intent,isNewIntent)
  local text
  if intent.getData() then
    local data=intent.getData()
    local scheme=data.getScheme()
    local host=data.getHost()
    if scheme=="http" or scheme=="https" then
      if host=="github.com" then
        text=tostring(data)
      end
    end
   elseif intent.getStringExtra(Intent.EXTRA_TEXT) then
    text=intent.getStringExtra(Intent.EXTRA_TEXT)
  end
  if not text then
    return
  end

  inputEdit.setText(text)
end

---开始转换url
---@param callback fun(newUrl:string) 回调
function startConvertUrl(callback)
  inputEdit.setError(nil)
  local state,message=pcall(getConvertedUrl)
  if state then
    callback(message)
   else
    inputEdit.setError(message:match(": (.+)") or message)
    inputEdit.requestFocus()
  end
  return state,message
end


---渲染HTML
---@param source string
function getSpannedFromHtml(source)
  --local spanned=MarkDown.fromMarkdown(source,imageGetter,messageView);
  local spanned=Html.fromHtml(source)
  return spanned
end

---切换分类，但不切换单选框
---@param categoryKey string 分类key
function changeCategory(categoryKey)
  --TODO: 支持categoryKey为nil的情况，当前平台没有转换器时会触发。
  --判断当前转换器是否相同，如果相同则不需要执行下面的操作了
  if nowConverterConfigs and nowConverterConfigs.key==categoryKey then
    return
  end

  nowConverterConfigs=converterConfigs[categoryKey]
  if nowConverterConfigs and nowConverterConfigs.message then
    messageView.setText(getSpannedFromHtml(nowConverterConfigs.message))
    messageView.setVisibility(View.VISIBLE)
   else
    messageView.setText(nil)
    messageView.setVisibility(View.GONE)
  end
  if nowConverterConfigs and nowConverterConfigs.supportUrl then
    supportButton.setVisibility(View.VISIBLE)
   else
    supportButton.setVisibility(View.GONE)
  end
end

---切换分类和单选框
function changeCategoryRadio(key,smooth,focus)
  --判断当前转换器是否相同，如果相同则不需要执行下面的操作了
  if not focus and (not nowPlatform or nowConverterConfigs and nowConverterConfigs.key==key) then
    return
  end
  local radioButton
  if key then
    for index,category in ipairs(nowPlatform.categories) do
      if category[2]==key then
        radioButton=radioGroup.getChildAt(index-1) or radioButton
        break
      end
    end
  end
  if radioButton then
    radioButton.setChecked(true)
    changeCategory(radioButton.tag)
    scrollToView(radioScrollView,radioButton,smooth)
   else
    changeCategory(nil)
  end
  --TODO: 使用 LuaDB 存储数据
  activity.setSharedData(KEY_SELECTED_FORMATTER:format(nowPlatform.key),key)
  refreshMenus()
end

---切换平台
---@param platformKey string
function changePlatform(platformKey)
  --changeCategoryRadio(nil,false)
  local platformConfig=platformKey2ConfigMap[platformKey]
  nowPlatform=platformConfig
  --移除旧的转换器单选框
  radioGroup.removeAllViews()
  --添加转换器单选框
  local selectedConverterKey=activity.getSharedData(KEY_SELECTED_FORMATTER:format(platformKey))
  local isSelectedConverterAvailable=false
  ---@type string|nil
  local firstAvailableConverterKey

  for index,category in ipairs(platformConfig.categories) do
    local name,converterKey=category[1],category[2]
    ---@type ConverterConfig | nil
    local converter=converterKey and converterConfigs[converterKey]
    if converter and not(converter.hide) then
      ---@type boolean
      local isAvailable=not not converter

      local radioButton=RadioButton(activity)
      radioGroup.addView(radioButton)
      radioButton.setText(name)
      radioButton.setTag(converterKey)
      radioButton.setOnClickListener(onRadioButtonClickListener)
      radioButton.setEnabled(isAvailable)
      local layoutParams=radioButton.getLayoutParams()
      layoutParams.height=ViewGroup.LayoutParams.MATCH_PARENT
      radioButton.setLayoutParams(layoutParams)

      --优先选择受支持的转换器
      if isAvailable then
        if converterKey==selectedConverterKey then
          isSelectedConverterAvailable=true
        end
        if not firstAvailableConverterKey then
          firstAvailableConverterKey=converterKey
        end
      end
    end
  end

  if not isSelectedConverterAvailable then
    selectedConverterKey=firstAvailableConverterKey
  end

  --默认勾选
  radioGroup.post({
    run=function()
      changeCategoryRadio(selectedConverterKey,false,true)
    end
  })
  activity.setSharedData(KEY_PLATFORM_SELECTED_FORMAT:format(platformsGroupName),platformKey)
end

--平滑滚动到视图
---@param parent ScrollView 父容器
---@param view View 控件
---@param smooth 平滑滚动
function scrollToView(parent,view,smooth)
  local x=view.getLeft()-(parent.getWidth()-view.getWidth())/2
  local y=view.getTop()-(parent.getHeight()-view.getHeight())/2
  if smooth then
    parent.smoothScrollTo(x,y)
   else
    parent.scrollTo(x,y)
  end
end

function onRadioButtonClick(view)
  changeCategoryRadio(view.tag,true)
end

function onResume()
  if needRecreate() then
    activity.recreate()
  end
end

onRadioButtonClickListener=View.OnClickListener({onClick=onRadioButtonClick})

startButton.onClick=function()
  startConvertUrl(function(newUrl)
    local dialog=AlertDialog.Builder(this)
    .setTitle("转换后的内容")
    .setMessage(newUrl)
    .setPositiveButton(android.R.string.ok,nil)
    .setNegativeButton(android.R.string.copy,nil)
    .show()
    local positiveButton=dialog.getButton(AlertDialog.BUTTON_NEGATIVE)
    positiveButton.onClick=function()
      activity.getSystemService(Context.CLIPBOARD_SERVICE).setPrimaryClip(ClipData.newPlainText(nil,newUrl))
      toast("已复制到剪贴板")
    end
    DialogHelper.setMessageIsSelectable(dialog,true)
  end)
end

startAndOpenButton.onClick=function()
  startConvertUrl(openInBrowser)
end

startAndShareButton.onClick=function()
  startConvertUrl(function(newUrl)
    local intent=Intent(Intent.ACTION_SEND)
    intent.setType("text/plain")
    intent.putExtra(Intent.EXTRA_SUBJECT, "分享")
    intent.putExtra(Intent.EXTRA_TEXT, newUrl)
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    activity.startActivity(Intent.createChooser(intent,"分享到:"))
  end)
end

pasteButton.onClick=function()
  local text=activity.getSystemService(Context.CLIPBOARD_SERVICE).getText()
  inputEdit.setText(text)
end

supportButton.onClick=function()
  if nowConverterConfigs.supportUrl then
    openInBrowser(nowConverterConfigs.supportUrl)
  end
end

messageView.onTouch=function(view,event)
  local action=event.action
  if action==MotionEvent.ACTION_DOWN then
    view.requestFocus()
  end
end

moreCategoriesButton.onClick=function()
  local items={}
  local keys={}
  if not nowPlatform then
    return
  end
  local categories=nowPlatform.categories
  local position=-1
  for i=1,#categories do
    local key=categories[i][2]
    if converterConfigs[key] then
      table.insert(items,categories[i][1])
      table.insert(keys,key)
    end
    if nowConverterConfigs and nowConverterConfigs.key==key then
      position=tonumber(#items)-1
    end
  end

  local dialog=AlertDialog.Builder(this)
  .setTitle("转换器分类")
  .setSingleChoiceItems(items,position,function(dialog,position)
    changeCategoryRadio(keys[position+1],true)
  end)
  .setPositiveButton(android.R.string.ok,nil)
  .show()
end

---修复initConverterConfigs，自动完善converterConfigs数据
---@param converterConfigs table<string,ConverterConfig>
function fixConverterConfigs(converterConfigs)
  for key,converterConfig in pairs(converterConfigs) do
    converterConfig.key=key
  end
end

customConverterConfigsMD5=loadConverterCustomConfigs(converterConfigs)
customPlatformConfigsMD5=loadPlatformCustomConfigs(platformConfigs)

fixConverterConfigs(converterConfigs)

--建立platformKey2ConfigMap映射
for i=1,#platformConfigs do
  local platformConfig=platformConfigs[i]
  platformKey2ConfigMap[platformConfig.key]=platformConfig
end

--nowPlatform=toolConfigs.platforms[1]


if #platformConfigs>1 then
  actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_TABS)
  local selectedPlatformKey=activity.getSharedData(KEY_PLATFORM_SELECTED_FORMAT:format(platformsGroupName))
  local showCount=#platformConfigs
  for i=1,showCount do 
    if platformConfigs[i].hide then
      showCount=showCount-1
    end
  end
  for i=1,showCount do
    local platformConfig=platformConfigs[i]
    if platformConfig.hide then return end
    local tab = actionBar.newTab()
    .setText(platformConfig.name)
    .setTabListener(ActionBar.TabListener({
      onTabSelected=function()
        changePlatform(platformConfig.key)
      end
    }))
    actionBar.addTab(tab)
    if platformConfig.key==selectedPlatformKey then
      tab.select()
    end
  end
 else
  changePlatform(platformConfigs[1].key)
end


parseIntent(activity.getIntent(),false)

local agreedUserTermVersion=activity.getSharedData(KEY_TERM_USER)
local agreedPrivacyTermVersion=activity.getSharedData(KEY_TERM_PRIVACY)
if agreedUserTermVersion~=VERSION_TERM_USER
  or agreedPrivacyTermVersion~=VERSION_TERM_PRIVACY then
  local wecomeHtml=readFile(luajava.luadir.."/welcome.html")
  local dialog=AlertDialog.Builder(this)
  .setTitle("欢迎使用")
  .setMessage(Html.fromHtml(wecomeHtml))
  .setCancelable(false)
  .setPositiveButton("同意",function()
    activity.setSharedData(KEY_TERM_USER,VERSION_TERM_USER)
    activity.setSharedData(KEY_TERM_PRIVACY,VERSION_TERM_PRIVACY)
    toast("您已签署用户协议与隐私政策，欢迎使用！")
  end)
  .setNegativeButton("不同意",function()
    activity.finish()
  end)
  .show()
  local messageView=dialog.findViewById(android.R.id.message)
  messageView.setTextIsSelectable(true)
  messageView.setMovementMethod(RTEditorMovementMethod.getInstance())
  messageView.requestFocus()
end

