"""Generates docs/architecture.drawio for the Generative AI Model Access project using drawpyo.

Run with: python3 scripts/generate_diagram.py
"""
import os

import drawpyo

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")

AWS4_BASE = (
    "sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;strokeColor=none;"
    "dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
    "fontSize=11;fontStyle=0;aspect=fixed;pointerEvents=1;"
)


def aws_style(icon_name, fill_color):
    return f"{AWS4_BASE}fillColor={fill_color};shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{icon_name};"


def add_node(page, name, x, y, icon_name, fill_color, width=64, height=64):
    node = drawpyo.diagram.Object(page=page, value=name)
    node.position = (x, y)
    node.geometry.width = width
    node.geometry.height = height
    node.apply_style_string(aws_style(icon_name, fill_color))
    return node


def add_group(page, name, x, y, width, height):
    group = drawpyo.diagram.Object(page=page, value=name)
    group.position = (x, y)
    group.geometry.width = width
    group.geometry.height = height
    group.apply_style_string(
        "rounded=0;whiteSpace=wrap;html=1;dashed=1;dashPattern=8 4;fillColor=none;"
        "strokeColor=#01A88D;verticalAlign=top;align=center;fontColor=#01A88D;fontSize=11;"
    )
    return group


def add_edge(page, source, target, label=None):
    edge = drawpyo.diagram.Edge(page=page, source=source, target=target, label=label)
    edge.waypoints = "orthogonal"
    edge.endArrow = "block"
    edge.startArrow = "none"
    edge.strokeColor = "#545B64"
    return edge


def build_diagram():
    file = drawpyo.File()
    file.file_name = "architecture.drawio"
    file.file_path = OUTPUT_DIR

    page = drawpyo.Page(file=file)
    page.name = "Generative AI Model Access"

    device = add_node(page, "Device", 40, 200, "client", "#232F3E")
    auth = add_node(page, "Authentication\n(Cognito)", 240, 40, "cognito", "#DD344C")
    rest_api = add_node(page, "REST API\n(API Gateway)", 240, 200, "api_gateway", "#E7157B")
    call_api = add_node(page, "Call API\n(Lambda)", 440, 200, "lambda_function", "#ED7100")
    access_models = add_node(page, "Access models\n(Bedrock runtime)", 640, 200, "machine_learning", "#01A88D")

    group = add_group(page, "Text summarization, image generation, virtual assistant", 800, 150, 260, 140)
    bedrock_models = add_node(page, "Foundation models\n(Amazon Bedrock)", 840, 195, "machine_learning", "#01A88D")

    add_edge(page, device, auth, "Authentication")
    add_edge(page, device, rest_api, "Prompt / Response")
    add_edge(page, rest_api, call_api, "Invoke / Response")
    add_edge(page, call_api, access_models, "API call / Response")
    add_edge(page, access_models, bedrock_models, "Prompt / Response")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    file.write()
    print(f"Wrote {os.path.join(OUTPUT_DIR, file.file_name)}")


if __name__ == "__main__":
    build_diagram()
