//
//  File.swift
//  Demo
//
//  Created by 李旭 on 2024/12/22.
//

import Foundation

import ZIPFoundation

public struct XLSXFile {
    // 保存文件的路径
    public let filepath: String
    
    // 用于生成 XLSX 文件
    private let archive: Archive
    
    // 初始化时打开一个文件的 ZIP 归档（也就是一个 XLSX 文件）
    public init?(filepath: String) throws {
        self.filepath = filepath
        let archiveURL = URL(fileURLWithPath: filepath)
        // 使用抛出初始化器
        self.archive = try Archive(url: archiveURL, accessMode: .create)
        
        // 将以上内容保存到 ZIP 文件
        try archive.addEntry(with: "[Content_Types].xml", type: .file, uncompressedSize: Int64(contentTypesXML.count), provider: { _, _ -> Data in
            return self.contentTypesXML.data(using: .utf8)!
        })
        
        try archive.addEntry(with: "_rels/.rels", type: .file, uncompressedSize: Int64(relsXML.count)) { _, _ in
            relsXML.data(using: .utf8)!
        }
        
        try archive.addEntry(with: "xl/workbook.xml", type: .file, uncompressedSize: Int64(xlWorkbookXML.count), provider: { _, _ in
            xlWorkbookXML.data(using: .utf8)!
        })
        
        try archive.addEntry(with: "xl/_rels/workbook.xml.rels", type: .file, uncompressedSize: Int64(xlRelsWorkbookRelsXMLRels.count), provider: { _, _ in
            xlRelsWorkbookRelsXMLRels.data(using: .utf8)!
        })
                  
        try archive.addEntry(with: "xl/styles.xml", type: .file, uncompressedSize: Int64(stylesXML.count), provider: { _, _ in
            stylesXML.data(using: .utf8)!
        })
        
        try archive.addEntry(with: "xl/worksheets/sheet1.xml", type: .file, uncompressedSize: Int64(sheetXML.count), provider: { _, _ in
            sheetXML.data(using: .utf8)!
        })
        
        print("Empty Excel file created successfully at \(filepath)")
    }
    
    let xlRelsWorkbookRelsXMLRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <!-- 工作表关系 -->
        <Relationship Id="rId1"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"
            Target="worksheets/sheet1.xml"/>
    
        <!-- 样式表关系（必需） -->
        <Relationship Id="rId2"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
            Target="styles.xml"/>
    
        <!-- 主题关系（推荐） -->
        <Relationship Id="rId3"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"
            Target="theme/theme1.xml"/>
    
        <!-- 共享字符串关系（如果使用共享字符串） -->
        <!--
        <Relationship Id="rId4"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"
            Target="sharedStrings.xml"/>
        -->
    </Relationships>
    """
    
    // 创建 `[Content_Types].xml` 文件
    let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
        <Default Extension="xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml" />
        <!-- 文档属性 -->
        <Override PartName="/docProps/app.xml"
            ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml" />
        <Override PartName="/docProps/core.xml"
            ContentType="application/vnd.openxmlformats-package.core-properties+xml" />
        <!-- 工作簿结构 -->
        <Override PartName="/xl/workbook.xml"
            ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml" />
        <Override PartName="/xl/_rels/workbook.xml.rels" 
            ContentType="application/vnd.openxmlformats-package.relationships+xml" />
    
        <!-- 工作表 -->
        <Override PartName="/xl/worksheets/sheet1.xml"
            ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml" />
    
        <!-- 样式和主题 -->
        <Override PartName="/xl/styles.xml"
            ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml" />
        <Override PartName="/xl/theme/theme1.xml"
            ContentType="application/vnd.openxmlformats-officedocument.theme+xml" />
        <!-- 共享字符串表 -->
        <Override PartName="/xl/sharedStrings.xml"
            ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml" />
    </Types>
    """
    
    // 创建 `_rels/.rels` 文件
    let relsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
            Target="xl/workbook.xml" />
        <Relationship Id="rId3"
            Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
            Target="docProps/core.xml" />
        <Relationship Id="rId2"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"
            Target="docProps/app.xml" />
    </Relationships>
    """
    
    // 创建 `xl/workbook.xml` 文件
    let xlWorkbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <fileVersion appName="xl" lastEdited="5" lowestEdited="5" rupBuild="9302"/>
        <workbookPr defaultThemeVersion="164011" date1904="false"/>
        <bookViews>
            <workbookView xWindow="240" yWindow="105" windowWidth="19200" windowHeight="11760"/>
        </bookViews>
        <sheets>
            <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
        <calcPr calcId="191029" calcMode="auto" fullCalcOnLoad="1"/>
    </workbook>
    """
    
    // 创建 `xl/worksheets/sheet1.xml` 文件
    let sheetXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
               xmlns:etc="http://www.wps.cn/officeDocument/2017/etCustomData"
    >
        <sheetPr>
            <outlinePr summaryBelow="1" summaryRight="1"/>
        </sheetPr>
        <dimension ref="A1:B2"/>
        <sheetViews>
            <sheetView tabSelected="true" workbookViewId="0">
                <selection activeCell="A1" sqref="A1"/>
            </sheetView>
        </sheetViews>
        <sheetFormatPr defaultRowHeight="15" defaultColWidth="10"/>
        <sheetData>
            <row r="1">
                <c r="A1" t="s"><v>0</v></c>
                <c r="B1" t="s"><v>1</v></c>
            </row>
            <row r="2">
                <c r="A2" t="n"><v>42</v></c>
                <c r="B2" t="n"><v>3.14</v></c>
            </row>
        </sheetData>
        <pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>
        <pageSetup paperSize="9" orientation="portrait" r:id="rId1"/>
    </worksheet>
    """
    
    // 创建 `xl/styles.xml` 文件（空的样式文件）
    let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="1">
        <font>
          <sz val="11"/>
          <color theme="1"/>
          <name val="宋体"/>
          <family val="2"/>
          <scheme val="minor"/>
        </font>
      </fonts>
    
      <fills count="2">
        <fill>
          <patternFill patternType="none"/>
        </fill>
        <fill>
          <patternFill patternType="gray125"/>
        </fill>
      </fills>
    
      <borders count="1">
        <border>
          <left/>
          <right/>
          <top/>
          <bottom/>
          <diagonal/>
        </border>
      </borders>
    
      <cellStyleXfs count="1">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
      </cellStyleXfs>
    
      <cellXfs count="1">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
      </cellXfs>
    
      <cellStyles count="1">
        <cellStyle name="Normal" xfId="0" builtinId="0"/>
      </cellStyles>
    
      <dxfs count="0"/>
      <tableStyles count="0" defaultTableStyle="TableStyleMedium9" defaultPivotStyle="PivotStyleMedium9"/>
    </styleSheet>
    """
}
